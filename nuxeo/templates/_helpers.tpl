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
{{- $fullname := include "nuxeo.fullname.without.nodeType" . -}}
{{- with .nuxeoNodeType }}
{{- $fullname = printf "%s%s" $fullname (ternary "" (printf "-%s" .) (eq . "single")) -}}
{{- end -}}
{{- $fullname -}}
{{- end -}}

{{- define "nuxeo.fullname.without.nodeType" -}}
{{- $fullname := "" -}}
{{- if .Values.fullnameOverride -}}
{{- $fullname = .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name }}
{{- $fullname = .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $fullname = printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- with .suffix }}
{{- $fullname = printf "%s%s" $fullname . -}}
{{- end -}}
{{- $fullname -}}
{{- end -}}


{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "nuxeo.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "nuxeo.labels" -}}
app.kubernetes.io/name: {{ include "nuxeo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- with .nuxeoNodeType }}
app.kubernetes.io/component: {{ . }}
{{- end }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "nuxeo.chart" . }}
{{ include "nuxeo.selectorLabels" . }}
chart: {{ include "nuxeo.chart" .  | quote }}
release: {{ .Release.Name | quote }}
heritage: {{ .Release.Service | quote }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "nuxeo.selectorLabels" -}}
app: {{ include "nuxeo.fullname.without.nodeType" . }}
{{- with .nuxeoNodeType }}
nuxeoNode: {{ . }}
{{- end }}
tier: {{ ternary "backend" "frontend" (eq (default "single" .nuxeoNodeType) "worker") }}
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
Return true if the deployment needs to be rolled.
*/}}
{{- define "nuxeo.deployment.roll" -}}
{{- if .Values.image.pullPolicy -}}
  {{- if eq "Always" .Values.image.pullPolicy -}}
    {{- true -}}
  {{- else -}}
    {{- false -}}
  {{- end -}}
{{- else -}}
  {{- if eq "latest" (toString .Values.image.tag) -}}
    {{- true -}}
  {{- else -}}
    {{- false -}}
  {{- end -}}
{{- end -}}

{{- end -}}

{{/*
Return the Nuxeo architecure, "singleNode" by default.
*/}}
{{- define "nuxeo.architecture" -}}
    {{- default "singleNode" .Values.architecture -}}
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

{{/*
Validate binary storage configuration: only one type of storage can be enabled.
*/}}
{{- define "nuxeo.validateValues.binaryStorage" -}}
{{- if or (or (and .Values.googleCloudStorage.enabled .Values.amazonS3.enabled) (and .Values.googleCloudStorage.enabled .Values.persistentVolumeStorage.enabled)) (and .Values.amazonS3.enabled .Values.persistentVolumeStorage.enabled) -}}
{{-   printf "\n" -}}
nuxeo binary storage configuration:

  Only one type of binary storage can be enabled among:
    - Google Cloud Storage
    - Amazon S3
    - PersistentVolume

  Please set googleCloudStorage.enabled=true or amazonS3.enabled=true or persistentVolumeStorage.enabled=true.
{{- end -}}
{{- end -}}

{{/*
Validate database configuration: can enable either MongoDB or PostgreSQL but not both.
*/}}
{{- define "nuxeo.validateValues.database" -}}
{{- if and .Values.mongodb.enabled .Values.postgresql.enabled -}}
{{-   printf "\n" -}}
nuxeo database configuration:

  MongoDB and PostgreSQL databases cannot be enabled at the same time.
  Please set either mongodb.enabled=true or postgresql.enabled=true.
{{- end -}}
{{- end -}}

{{/*
Validate Kafka/Redis mutual exclusion: can enable either kafka or Redis but not both.
*/}}
{{- define "nuxeo.validateValues.kafkaRedis" -}}
{{- if and .Values.kafka.enabled .Values.redis.enabled -}}
{{-   printf "\n" -}}
kafka and redis mutual exclusion:

  Kafka and Redis cannot be enabled at the same time.
  Please set either kafka.enabled=true or redis.enabled=true.
{{- end -}}
{{- end -}}

{{/*
Template for an Opaque secret manifest, using a dictionary as scope:
  - .: root context
  - name: secret name
  - data: secret data, map of key value pairs
  - dataType: "data" or "stringData", depending on whether the data values are arbitrary or base64-encoded strings
*/}}
{{- define "nuxeo.secret" -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .name }}
  labels: {{- template "nuxeo.labels" . | nindent 4 }}
type: Opaque
{{ .dataType }}: {{ toYaml .data | nindent 2 }}
{{- end -}}

{{/*
Return the list of node types depending on the architecture.
*/}}
{{- define "nuxeo.nodeTypes" -}}
{{- if eq (include "nuxeo.architecture" .) "api-worker" -}}
    api,worker
{{- else -}}
    single
{{- end -}}
{{- end -}}
