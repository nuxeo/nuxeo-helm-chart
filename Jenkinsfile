/*
 * (C) Copyright 2020-2025 Nuxeo (http://nuxeo.com/) and others.
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
import java.time.LocalDate
import java.time.format.DateTimeFormatter

library identifier: "platform-ci-shared-library@v0.0.67"

String getChartVersion(chart) {
  container('base') {
    return sh(returnStdout: true, script: "yq read ${chart}/Chart.yaml version").trim()
  }
}

def buildTestStage(String environment) {
  return {
    stage("Deploy ${environment} environment") {
      container('base') {
        nxWithGitHubStatus(context: "tests/${environment}", message: "Test the ${environment} deployment") {
          def testNamespace = "${CURRENT_NAMESPACE}-nuxeo-helm-chart-${BRANCH_NAME}-${BUILD_NUMBER}-${environment}".toLowerCase()
          nxWithHelmfileDeployment(namespace: testNamespace, environment: environment,
              secrets: [[name: 'platform-tls', namespace: 'platform'], [name: 'instance-clid', namespace: 'platform']]) {
            def ingressUrl = "https://${NAMESPACE}.platform.dev.nuxeo.com/nuxeo"
            def serviceUrl = "http://nuxeo.${NAMESPACE}.svc.cluster.local/nuxeo"
            // check running status
            int retryCount = 5
            sh "ci/scripts/running-status.sh ${serviceUrl} ${retryCount}"
            // check ingress
            sh "ci/scripts/running-status.sh ${ingressUrl} ${retryCount}"
          }
        }
      }
    }
  }
}

pipeline {
  agent {
    label "jenkins-base"
  }
  options {
    buildDiscarder(logRotator(daysToKeepStr: '60', numToKeepStr: '60', artifactNumToKeepStr: '5'))
    disableConcurrentBuilds(abortPrevious: true)
    githubProjectProperty(projectUrlStr: 'https://github.com/nuxeo/nuxeo-helm-chart')
  }
  environment {
    CHART_NAME = 'nuxeo'
    CHART_DESCRIPTOR = "${CHART_NAME}/Chart.yaml"
    CURRENT_NAMESPACE = nxK8s.getCurrentNamespace()
    VERSION = nxUtils.getVersion(baseVersion: getChartVersion("${CHART_NAME}"))
    CHART_ARCHIVE = "${CHART_NAME}-${VERSION}.tgz"
    CHART_REPO_INTERNAL = 'http://chartmuseum:8080/api/charts'
    CHART_REPO_INTERNAL_CREDENTIALS = 'chartmuseum'
    CHART_REPO_PUBLIC = 'https://packages.nuxeo.com/repository/helm-releases-public/'
    CHART_REPO_PUBLIC_CREDENTIALS = 'packages.nuxeo.com-auth'
    JIRA_PROJECT = 'NXP'
    JIRA_MOVING_VERSION = 'helm-chart-next'
    JIRA_RELEASED_VERSION = "helm-chart-${VERSION}"
  }
  stages {
    stage('Helm package') {
      steps {
        container('base') {
          nxWithGitHubStatus(context: 'package', message: 'Package the Helm Chart') {
            script {
              currentBuild.description = "${VERSION}"
              echo "Update chart to version ${VERSION}"
              sh "yq write -i ${CHART_DESCRIPTOR} version ${VERSION}"

              echo "Package chart version: ${VERSION}"
              sh "helm package ${CHART_NAME}"
            }
          }
        }
      }
      post {
        always {
          archiveArtifacts artifacts: "${CHART_ARCHIVE}"
        }
      }
    }
    stage('Test chart') {
      steps {
        script {
          def stages = [:]
          for (env in ['default', 'cluster', 'third-party-auth']) {
            stages["Deploy ${env} environment"] = buildTestStage(env)
          }
          parallel stages
        }
      }
    }
    stage('Upload Helm Chart Package') {
      steps {
        container('base') {
          nxWithGitHubStatus(context: 'upload', message: 'Upload the Helm Chart Package') {
            script {
              echo "Upload chart archive ${CHART_ARCHIVE}"
              if (nxUtils.isPullRequest()) {
                nxUtils.uploadDataBinary(credentialsId: "${CHART_REPO_INTERNAL_CREDENTIALS}", url: "${CHART_REPO_INTERNAL}", file: env.CHART_ARCHIVE)
              } else {
                nxUtils.uploadFile(credentialsId: "${CHART_REPO_PUBLIC_CREDENTIALS}", url: "${CHART_REPO_PUBLIC}", file: env.CHART_ARCHIVE)
              }
            }
          }
        }
      }
    }
    stage('Release Project') {
      when {
        expression { !nxUtils.isPullRequest() }
      }
      steps {
        container('base') {
          nxWithGitHubStatus(context: 'release', message: 'Release') {
            script {
              nxProject.release(
                jql: "project = ${JIRA_PROJECT} and fixVersion = ${JIRA_MOVING_VERSION}",
                newJiraVersion: [
                    project    : env.JIRA_PROJECT,
                    name       : env.JIRA_RELEASED_VERSION,
                    releaseDate: LocalDate.now().format(DateTimeFormatter.ISO_LOCAL_DATE),
                    released   : true,
                ],
                jiraMovingVersionName: env.JIRA_MOVING_VERSION,
              )
            }
          }
        }
      }
    }
  }
  post {
    always {
      script {
        if (nxUtils.isPullRequest()) {
          nxUtils.setBuildDescription()
        } else {
          nxUtils.setReleaseDescription()
          nxJira.updateIssues()
          nxUtils.notifyReleaseStatusIfNecessary()
        }
      }
    }
  }
}
