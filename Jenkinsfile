/*
 * (C) Copyright 2020 Nuxeo (http://nuxeo.com/) and others.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
properties([
  [$class: 'GithubProjectProperty', projectUrlStr: 'https://github.com/nuxeo/nuxeo-helm-chart/'],
  [$class: 'BuildDiscarderProperty', strategy: [$class: 'LogRotator', daysToKeepStr: '60', numToKeepStr: '60', artifactNumToKeepStr: '5']],
  disableConcurrentBuilds(),
])

void setGitHubBuildStatus(String context, String message, String state) {
  step([
    $class: 'GitHubCommitStatusSetter',
    reposSource: [$class: 'ManuallyEnteredRepositorySource', url: 'https://github.com/nuxeo/nuxeo-helm-chart'],
    contextSource: [$class: 'ManuallyEnteredCommitContextSource', context: context],
    statusResultSource: [$class: 'ConditionalStatusResultSource', results: [[$class: 'AnyBuildResult', message: message, state: state]]],
  ])
}

String getPRVersion() {
  // get the current chart version and append PR specific versioning
  String version = sh(returnStdout: true, script: "grep version ${CHART_NAME}/Chart.yaml | awk '{print \$2}'").trim()
  return version + "-${BRANCH_NAME}-${BUILD_NUMBER}"
}

String getNextVersion() {
  // read the VERSION file written by 'jx step next-version'
  return sh(returnStdout: true, script: 'head -n 1 VERSION')
}

def nextVersion

pipeline {
  agent {
    label "jenkins-jx-base"
  }
  environment {
    CHART_NAME = 'nuxeo'
    CHART_REPOSITORY = 'http://jenkins-x-chartmuseum:8080'
    TEST_NAMESPACE = "nuxeo-helm-chart-${BRANCH_NAME}-${BUILD_NUMBER}".toLowerCase()
    TEST_RELEASE = 'test-release'
    TEST_K8S_RESSOURCE = "${TEST_RELEASE}-${CHART_NAME}"
    TEST_SERVICE_DOMAIN = "${TEST_K8S_RESSOURCE}.${TEST_NAMESPACE}.svc.cluster.local"
    TEST_ROLLOUT_STATUS_TIMEOUT = '5m'
  }
  stages {
    //  abort if the build is triggered by the release commit push to master, see the 'GitHub release' stage
    stage('Abort release build') {
      when {
        expression {
          return sh(returnStdout: true, script: 'git log -1 --pretty=%B | head -n 1').startsWith('release')
        }
      }
      steps {
        container('jx-base') {
          script {
            currentBuild.result = 'ABORTED';
            currentBuild.description = 'Build triggered from a release commit, aborting.'
            error(currentBuild.description)
          }
        }
      }
    }
    stage('Helm release') {
      steps {
        setGitHubBuildStatus('helm-release', 'Build and release Helm chart', 'PENDING')
        container('jx-base') {
          script {
            if (BRANCH_NAME == 'master') {
              // Update chart version to the next semantic version.
              // This also:
              //   - Adds a release commit that is pushed to master by the next stage.
              //     That's why we need to locally checkout the master branch first since we're on a detached head.
              //   - Writes a VERSION file that is read to upload the chart package and create a Git tag in the next stage.
              sh """
                git checkout master
                jx step next-version --dir=${CHART_NAME} --filename=Chart.yaml
              """
            } else {
              // Update chart version to a PR version.
              sh "jx step next-version --dir=${CHART_NAME} --filename=Chart.yaml --version=${getPRVersion()}"
            }
            nextVersion = getNextVersion()
          }
          // Unfortunately, 'jx step helm build' and 'jx step helm release' sometimes fail with an obscure error:
          // "error: failed to build the dependencies of chart '.': failed to run 'helm dependency build' command in directory '.', ..."
          // Let's use helm directly to update the dependencies and package the chart, then the ChartMuseum API to upload the package.
          withCredentials([usernameColonPassword(credentialsId: 'jenkins-x-chartmuseum', variable: 'CHARTMUSEUM_AUTH')]) {
            script {
              // initialize Helm and package chart
              sh """
                helm init --client-only

                helm repo add kubernetes-charts https://kubernetes-charts.storage.googleapis.com/
                helm repo add kubernetes-charts-incubator http://storage.googleapis.com/kubernetes-charts-incubator
                helm repo add bitnami https://charts.bitnami.com/bitnami

                helm dependency update ${CHART_NAME}

                helm package ${CHART_NAME}
              """

              // install the chart into a test namespace that will be cleaned up afterwards
              sh """
                jx step helm install ${CHART_NAME} \
                  --name=${TEST_RELEASE} \
                  --namespace=${TEST_NAMESPACE} \
                  --set=nuxeo.image.tag=11.x # TODO remove when NXP-28504 is done and the latest tag (default) is available
              """

              // check deployment status, exits if not OK
              sh """
                kubectl rollout status deployment ${TEST_K8S_RESSOURCE} \
                  --namespace=${TEST_NAMESPACE} \
                  --timeout=${TEST_ROLLOUT_STATUS_TIMEOUT}
              """

              // check running status
              def runningStatus = sh(returnStatus: true, script: "./running-status.sh http://${TEST_SERVICE_DOMAIN}/nuxeo")
              if (runningStatus != 0) {
                currentBuild.result = 'FAILURE';
                currentBuild.description = "Running status is not OK."
                error(currentBuild.description)
              }

              // upload package to the ChartMuseum
              sh "curl --fail -u '${CHARTMUSEUM_AUTH}' --data-binary '@${CHART_NAME}-${nextVersion}.tgz' ${CHART_REPOSITORY}/api/charts"
            }
          }
        }
      }
      post {
        always {
          container('jx-base') {
            // uninstall the chart
            sh """
              jx step helm delete ${TEST_RELEASE} \
                --namespace=${TEST_NAMESPACE} \
                --purge
            """
            // clean up the test namespace
            sh "kubectl delete namespace ${TEST_NAMESPACE} --ignore-not-found=true"
          }
        }
        success {
          setGitHubBuildStatus('helm-release', 'Build and release Helm chart', 'SUCCESS')
        }
        failure {
          setGitHubBuildStatus('helm-release', 'Build and release Helm chart', 'FAILURE')
        }
      }
    }
    stage('GitHub release') {
      when {
        branch 'master'
      }
      steps {
        container('jx-base') {
          script {
            def currentNamespace = sh(returnStdout: true, script: "jx --batch-mode ns | cut -d\\' -f2").trim()
            if (currentNamespace == 'platform-staging') {
              echo "Running in namespace ${currentNamespace}, skip GitHub release stage."
              return
            }
            setGitHubBuildStatus('github-release', 'GitHub release', 'PENDING')
            sh """
              # create the Git credentials
              jx step git credentials
              git config credential.helper store

              # push release commit added by the revious stage to master
              git push origin master:master

              # Git tag
              git tag ${nextVersion}
              git push --tags
            """
          }
        }
      }
      post {
        always {
          step([$class: 'JiraIssueUpdater', issueSelector: [$class: 'DefaultIssueSelector'], scm: scm])
        }
        success {
          setGitHubBuildStatus('github-release', 'GitHub release', 'SUCCESS')
        }
        failure {
          setGitHubBuildStatus('github-release', 'GitHub release', 'FAILURE')
        }
      }
    }
  }
}
