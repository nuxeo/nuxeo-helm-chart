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
library identifier: "platform-ci-shared-library@v0.0.11"

String getChartVersion(chart) {
  container('base') {
    return sh(returnStdout: true, script: "yq read ${chart}/Chart.yaml version").trim()
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
    CHART_SERVICE = 'http://chartmuseum:8080'
    TEST_RELEASE = 'test-release'
    TEST_K8S_RESSOURCE = "${TEST_RELEASE}-${CHART_NAME}"
    VERSION = nxUtils.getVersion(baseVersion: getChartVersion("${CHART_NAME}"), tagPrefix: '')
    CHART_ARCHIVE = "${CHART_NAME}-${VERSION}.tgz"
  }
  stages {
    stage('Helm package') {
      steps {
        container('base') {
          nxWithGitHubStatus(context: 'package', message: 'Package and upload Helm chart') {
            script {
              currentBuild.description = "${VERSION}"
              echo "Update chart to version ${VERSION}"
              sh "yq write -i ${CHART_DESCRIPTOR} version ${VERSION}"

              echo "Package chart version: ${VERSION}"
              sh "helm3 package ${CHART_NAME}"

              echo 'Test chart'
              // install the chart into a test namespace that will be cleaned up afterwards
              nxWithHelmfileDeployment() {
                // check running status
                sh "ci/running-status.sh http://${TEST_K8S_RESSOURCE}.${NAMESPACE}.svc.cluster.local/nuxeo"
              }

              echo "Upload chart archive ${CHART_ARCHIVE}"
              // upload package to the ChartMuseum
              nxUtils.uploadDataBinary(credentialsId: 'chartmuseum', url: "${CHART_SERVICE}/api/charts", file: env.CHART_ARCHIVE)
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
    stage('GitHub release') {
      when {
        expression { !nxUtils.isPullRequest() }
      }
      steps {
        container('base') {
          nxWithGitHubStatus(context: 'release', message: 'Release') {
            script {
              // tag the version - nuxeo-helm-chart doesn't follow the v1.2.3 convention
              nxGit.commitTagPush(tag: env.VERSION)
            }
          }
        }
      }
    }
  }
  post {
    always {
      script {
        nxJira.updateIssues()
      }
    }
  }
}
