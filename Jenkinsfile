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

void buildAndRelease() {
  sh """
    echo 'Build Helm chart'
    jx step helm build
    echo 'Release Helm chart'
    jx step helm release
  """
}

pipeline {
  agent {
    label "jenkins-jx-base"
  }
  environment {
    CHARTMUSEUM_CREDS = credentials('jenkins-x-chartmuseum')
  }
  stages {
    stage('Helm release') {
      when {
        branch 'master'
      }
      steps {
        setGitHubBuildStatus('helm-release', 'Build and release Helm chart', 'PENDING')
        container('jx-base') {
          dir('nuxeo') {
            buildAndRelease()
          }
        }
      }
      post {
        success {
          setGitHubBuildStatus('helm-release', 'Build and release Helm chart', 'SUCCESS')
        }
        failure {
          setGitHubBuildStatus('helm-release', 'Build and release Helm chart', 'FAILURE')
        }
      }
    }
  }
}
