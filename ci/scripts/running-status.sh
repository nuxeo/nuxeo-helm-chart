#!/bin/sh
set -e

curlCommand="curl $1/runningstatus -v --retry $2 --retry-connrefused"
echo "Running command: $curlCommand"
runningStatus=$($curlCommand)
echo Running status: $runningStatus

runtimeStatus=$(echo $runningStatus | jq -r '.runtimeStatus')
repositoryStatus=$(echo $runningStatus | jq -r '.repositoryStatus')
streamStatus=$(echo $runningStatus | jq -r '.streamStatus')

if [ "$runtimeStatus" = 'ok' -a "$repositoryStatus" = 'ok' -a "$streamStatus" = 'ok' ]; then
  exit 0
else
  exit 1
fi
