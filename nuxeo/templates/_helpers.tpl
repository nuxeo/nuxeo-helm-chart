{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "nuxeo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "nuxeo.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Compile all warnings into a single message, and call fail.
*/}}
{{- define "nuxeo.validateValues" -}}
{{- $messages := list -}}
{{- $messages := append $messages (include "nuxeo.validateValues.clustering" .) -}}
{{- $messages := append $messages (include "nuxeo.validateValues.binaryStorage" .) -}}
{{- $messages := append $messages (include "nuxeo.validateValues.database" .) -}}
{{- $messages := append $messages (include "nuxeo.validateValues.kafkaRedis" .) -}}
{{- $messages := without $messages "" -}}
{{- $message := join "\n" $messages -}}

{{- if $message -}}
{{-   printf "\n\nVALUES VALIDATION:\n%s" $message | fail -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a cloud provider is enabled for binary storage.
*/}}
{{- define "nuxeo.cloudProvider.enabled" -}}
{{- if or .Values.googleCloudStorage.enabled .Values.amazonS3.enabled -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a database is enabled.
*/}}
{{- define "nuxeo.database.enabled" -}}
{{- if or .Values.mongodb.enabled .Values.postgresql.enabled -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a Kafka or Redis is enabled.
*/}}
{{- define "nuxeo.kafkaRedis.enabled" -}}
{{- if or .Values.kafka.enabled .Values.redis.enabled -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Validate clustering configuration: if more than 1 replica, must enable:
  - A cloud provider for binary storage.
  - A database.
  - Kafka or Redis.
*/}}
{{- define "nuxeo.validateValues.clustering" -}}
{{- if and (gt (int .Values.replicaCount) 1) (not (and (include "nuxeo.cloudProvider.enabled" .) (and (include "nuxeo.database.enabled" .) (include "nuxeo.kafkaRedis.enabled" .)))) -}}
{{-   printf "\n" -}}
nuxeo clustering configuration:

  When deploying a Nuxeo cluster, ie. replicaCount > 1, the following must be enabled:
    {{- if not (include "nuxeo.cloudProvider.enabled" .) -}}
    {{-   printf "\n    " -}}
    - A cloud provider for binary storage. Please set either googleCloudStorage.enabled=true or amazonS3.enabled=true.
    {{- end -}}
    {{- if not (include "nuxeo.database.enabled" .) -}}
    {{-   printf "\n    " -}}
    - A database for metadata storage. Please set either mongodb.enabled=true or postgresql.enabled=true.
    {{- end -}}
    {{- if not (include "nuxeo.kafkaRedis.enabled" .) -}}
    {{-   printf "\n    " -}}
    - Kafka or Redis for the WorkManager, PubSub Service and Nuxeo Streams. Please set either kafka.enabled=true or redis.enabled=true.
    {{- end -}}
{{- end -}}
{{- end -}}

{{/* Validate binary storage configuration: can enable either Google Cloud Storage or Amazon S3 but not both. */}}
{{- define "nuxeo.validateValues.binaryStorage" -}}
{{- if and .Values.googleCloudStorage.enabled .Values.amazonS3.enabled -}}
{{-   printf "\n" -}}
nuxeo binary storage configuration:

  Google Cloud Storage and Amazon S3 cloud providers cannot be enabled at the same time.
  Please set either googleCloudStorage.enabled=true or amazonS3.enabled=true.
{{- end -}}
{{- end -}}

{{/* Validate database configuration: can enable either MongoDB or PostgreSQL but not both. */}}
{{- define "nuxeo.validateValues.database" -}}
{{- if and .Values.mongodb.enabled .Values.postgresql.enabled -}}
 {{-   printf "\n" -}}
 nuxeo database configuration:

  MongoDB and PostgreSQL databases cannot be enabled at the same time.
  Please set either mongodb.enabled=true or postgresql.enabled=true.
{{- end -}}
{{- end -}}

{{/* Validate Kafka/Redis mutual exclusion: can enable either kafka or Redis but not both . */}}
{{- define "nuxeo.validateValues.kafkaRedis" -}}
{{- if and .Values.kafka.enabled .Values.redis.enabled -}}
 {{-   printf "\n" -}}
 kafka and redis mutual exclusion:

  Kafka and Redis cannot be enabled at the same time.
  Please set either kafka.enabled=true or redis.enabled=true.
{{- end -}}
{{- end -}}

{{/*
Template for the secret manifest, using a dictionary as scope:
- .: root context
- key: secret name suffix
- val: string data
*/}}
{{- define "nuxeo.secret" -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ template "nuxeo.fullname" .}}-{{ .key }}
  labels:
    app: {{ template "nuxeo.fullname" . }}
    chart: {{ .Chart.Name }}-{{ .Chart.Version }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
type: Opaque
stringData: {{ .val | nindent 2 }}
{{- end -}}
