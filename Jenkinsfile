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
repositoryUrl = 'https://github.com/nuxeo/nuxeo-helm-chart/'

properties([
  [$class: 'GithubProjectProperty', projectUrlStr: repositoryUrl],
  [$class: 'BuildDiscarderProperty', strategy: [$class: 'LogRotator', daysToKeepStr: '60', numToKeepStr: '60', artifactNumToKeepStr: '5']],
  disableConcurrentBuilds(),
])

void setGitHubBuildStatus(String context, String message, String state) {
  step([
    $class: 'GitHubCommitStatusSetter',
    reposSource: [$class: 'ManuallyEnteredRepositorySource', url: repositoryUrl],
    contextSource: [$class: 'ManuallyEnteredCommitContextSource', context: context],
    statusResultSource: [$class: 'ConditionalStatusResultSource', results: [[$class: 'AnyBuildResult', message: message, state: state]]],
  ])
}

String getBuildVersion(chartDescriptor) {
  def currentVersion = sh(returnStdout: true, script: "grep version: ${chartDescriptor} | awk '{print \$2}'").trim()
  return BRANCH_NAME == 'master' ? getNextVersion(currentVersion) : getPRVersion(currentVersion)
}

String getNoSnapshotVersion(version) {
  return version.replace('-SNAPSHOT', '')
}

// x.y-SNAPSHOT -> x.y-PR-AA-B
String getPRVersion(version) {
  def noSnapshot = getNoSnapshotVersion(version)
  return "${noSnapshot}-${BRANCH_NAME}-${BUILD_NUMBER}"
}

String getNextVersion(version) {
  def nextVersion
  def noSnapshot = getNoSnapshotVersion(version)
  // find the latest tag if any
  sh "git fetch origin 'refs/tags/${noSnapshot}*:refs/tags/${noSnapshot}*'"
  def tag = sh(returnStdout: true, script: "git tag --sort=taggerdate --list '${noSnapshot}*' | tail -1 | tr -d '\n'")
  if (tag) {
    def versions = tag.split('\\.')
    nextVersion = "${versions[0]}.${versions[1]}.${versions[2].toInteger() + 1}"
    echo "Found tag ${tag}, next version will be ${nextVersion}"
  } else {
    nextVersion = noSnapshot + '.0' // first patch version for a new major or minor version
    echo "No tag found, next version will be ${nextVersion}"
  }
  return nextVersion
}

void updateVersion(version) {
  echo "Update chart to version ${version}"
  sh "sed -i 's/version:.*/version: ${version}/' ${CHART_DESCRIPTOR}"
}

pipeline {
  agent {
    label "jenkins-base"
  }
  environment {
    CHART_NAME = 'nuxeo'
    CHART_DESCRIPTOR = "${CHART_NAME}/Chart.yaml"
    CHART_SERVICE = 'http://chartmuseum:8080'
    TEST_NAMESPACE = "nuxeo-helm-chart-${BRANCH_NAME}-${BUILD_NUMBER}".toLowerCase()
    TEST_RELEASE = 'test-release'
    TEST_K8S_RESSOURCE = "${TEST_RELEASE}-${CHART_NAME}"
    TEST_SERVICE_DOMAIN = "${TEST_K8S_RESSOURCE}.${TEST_NAMESPACE}.svc.cluster.local"
    TEST_ROLLOUT_STATUS_TIMEOUT = '5m'
    BUILD_VERSION = getBuildVersion("${CHART_DESCRIPTOR}")
    CHART_ARCHIVE = "${CHART_NAME}-${BUILD_VERSION}.tgz"
  }
  stages {
    stage('Helm package') {
      steps {
        setGitHubBuildStatus('package', 'Package and upload Helm chart', 'PENDING')
        container('base') {
          script {
            currentBuild.description = "${BUILD_VERSION}"
            updateVersion("${BUILD_VERSION}")

            echo "Package chart version: ${BUILD_VERSION}"
            sh "helm3 package ${CHART_NAME}"

            echo 'Test chart'
            // install the chart into a test namespace that will be cleaned up afterwards
            sh "kubectl create namespace ${TEST_NAMESPACE}"
            sh "kubectl --namespace=platform get secret kubernetes-docker-cfg -ojsonpath='{.data.\\.dockerconfigjson}' | base64 --decode > /tmp/config.json"
            sh """
              kubectl create secret generic kubernetes-docker-cfg \
                --namespace=${TEST_NAMESPACE} \
                --from-file=.dockerconfigjson=/tmp/config.json \
                --type=kubernetes.io/dockerconfigjson --dry-run -o yaml | kubectl apply -f -
            """
            sh """
              helm3 install ${TEST_RELEASE} ${CHART_NAME} \
                --namespace=${TEST_NAMESPACE} \
                --values=ci/values.yaml
            """
            try {
              // check deployment status, exit if not OK
              sh """
                kubectl rollout status deployment ${TEST_K8S_RESSOURCE} \
                  --namespace=${TEST_NAMESPACE} \
                  --timeout=${TEST_ROLLOUT_STATUS_TIMEOUT}
              """
              // check running status
              sh "ci/running-status.sh http://${TEST_SERVICE_DOMAIN}/nuxeo"
            } catch (e) {
              sh """
                kubectl --namespace=${TEST_NAMESPACE} get all,configmaps,endpoints,ingresses
                kubectl --namespace=${TEST_NAMESPACE} describe pod --selector=app=${TEST_K8S_RESSOURCE}
                kubectl --namespace=${TEST_NAMESPACE} logs --selector=app=${TEST_K8S_RESSOURCE} --all-containers --tail=1000
              """
              throw e
            }

            echo "Upload chart archive ${CHART_ARCHIVE}"
            // upload package to the ChartMuseum
            withCredentials([usernameColonPassword(credentialsId: 'chartmuseum', variable: 'CHARTMUSEUM_AUTH')]) {
              sh 'curl -u $CHARTMUSEUM_AUTH --data-binary @$CHART_ARCHIVE $CHART_SERVICE/api/charts'
            }
          }
        }
      }
      post {
        always {
          container('base') {
            script {
              try {
                // uninstall the chart
                sh "helm3 uninstall ${TEST_RELEASE} --namespace=${TEST_NAMESPACE}"
              } finally {
                // clean up the test namespace
                sh "kubectl delete namespace ${TEST_NAMESPACE} --ignore-not-found=true"
              }
            }
          }
        }
        success {
          setGitHubBuildStatus('package', 'Package and upload Helm chart', 'SUCCESS')
        }
        failure {
          setGitHubBuildStatus('package', 'Package and upload Helm chart', 'FAILURE')
        }
      }
    }
    stage('GitHub release') {
      when {
        allOf {
          branch 'master'
          not {
            environment name: 'DRY_RUN', value: 'true'
          }
        }
      }
      steps {
        setGitHubBuildStatus('release', 'Release', 'PENDING')
        container('base') {
          script {
            sh """
              # add release commit and tag
              git commit -a -m "Release ${BUILD_VERSION}"
              git tag -a ${BUILD_VERSION} -m "Release ${BUILD_VERSION}"

              # create the Git credentials
              jx step git credentials
              git config credential.helper store

              # push tag
              git push origin ${BUILD_VERSION}
            """
          }
        }
      }
      post {
        always {
          step([$class: 'JiraIssueUpdater', issueSelector: [$class: 'DefaultIssueSelector'], scm: scm])
        }
        success {
          setGitHubBuildStatus('release', 'Release', 'SUCCESS')
        }
        failure {
          setGitHubBuildStatus('release', 'Release', 'FAILURE')
        }
      }
    }
  }
}
