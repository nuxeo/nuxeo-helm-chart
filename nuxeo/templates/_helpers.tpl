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
Return true if the deployment needs init scripts.
*/}}
{{- define "nuxeo.initScripts.needed" -}}
{{- if or (include "nuxeo.database.enabled" .) .Values.customContributions -}}
  {{- true -}}
{{- else -}}
  {{- false -}}
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
{{- define "nuxeo.binary.cloudProvider.enabled" -}}
{{- if or .Values.googleCloudStorage.enabled .Values.amazonS3.enabled -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a persistent volum claim with ReadWriteMany is enabled for binary storage.
*/}}
{{- define "nuxeo.binary.pvc.has-many" -}}
{{- if and .Values.persistentVolumeStorage.enabled (eq (first .Values.persistentVolumeStorage.accessModes) "ReadWriteMany") -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return true if the deployment is a cluster.
*/}}
{{- define "nuxeo.clustering.enabled" -}}
{{- if ne "singleNode" (include "nuxeo.architecture" .) -}}
    {{- true -}}
{{- else if gt (default 1 (int .Values.replicaCount)) 1 -}}
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
Return the database template.
*/}}
{{- define "nuxeo.database.template" -}}
{{- if .Values.mongodb.enabled -}}
mongodb
{{- else if .Values.postgresql.enabled -}}
postgresql
{{- else -}}
default
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
Return true if a persistent volum claim with ReadWriteMany is enabled for log storage.
*/}}
{{- define "nuxeo.log.pvc.has-many" -}}
{{- if and .Values.logs.persistence.enabled (eq (first .Values.logs.persistence.accessModes) "ReadWriteMany") -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Template for a secret manifest, using a dictionary as scope:
  - .: root context
  - name: secret name
  - type: secret type
  - data: secret data, map of key value pairs
  - dataType: "data" or "stringData", depending on whether the data values are arbitrary or base64-encoded strings
*/}}
{{- define "nuxeo.secret" -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .name }}
  labels: {{- include "nuxeo.labels" . | nindent 4 }}
type: {{ (default "Opaque" .type) }}
{{ .dataType }}: {{ toYaml .data | nindent 2 }}
{{- end -}}

{{/*
Returns the name of the mongodb secret to get auth from.
*/}}
{{- define "nuxeo.secret.mongodb.name" -}}
{{- if .Values.mongodb.auth.existingSecret -}}
{{- .Values.mongodb.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-%s" (include "nuxeo.fullname" .) "mongodb" -}}
{{- end -}}
{{- end -}}

{{/*
Returns the name of the postgresql secret to get auth from.
*/}}
{{- define "nuxeo.secret.postgresql.name" -}}
{{- if .Values.postgresql.auth.existingSecret -}}
{{- .Values.postgresql.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-%s" (include "nuxeo.fullname" .) "postgresql" -}}
{{- end -}}
{{- end -}}

{{/*
Returns the username of the postgresql auth.
*/}}
{{- define "nuxeo.secret.postgresql.auth.username" -}}
{{- if .Values.postgresql.auth.username -}}
{{- .Values.postgresql.auth.username -}}
{{- else -}}
{{- .Values.postgresql.username -}}
{{- end -}}
{{- end -}}

{{/*
Returns the password of the postgresql auth.
*/}}
{{- define "nuxeo.secret.postgresql.auth.password" -}}
{{- if .Values.postgresql.auth.password -}}
{{- .Values.postgresql.auth.password -}}
{{- else -}}
{{- .Values.postgresql.password -}}
{{- end -}}
{{- end -}}

{{/*
Returns the name of the elasticsearch secret to get auth from.
*/}}
{{- define "nuxeo.secret.elasticsearch.name" -}}
{{- if .Values.elasticsearch.auth.existingSecret -}}
{{- .Values.elasticsearch.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-%s" (include "nuxeo.fullname" .) "elasticsearch" -}}
{{- end -}}
{{- end -}}

{{/*
Returns the username of the elasticsearch auth.
*/}}
{{- define "nuxeo.secret.elasticsearch.auth.username" -}}
{{- if .Values.elasticsearch.auth.username -}}
{{- .Values.elasticsearch.auth.username -}}
{{- else -}}
{{- .Values.elasticsearch.basicAuth.username -}}
{{- end -}}
{{- end -}}

{{/*
Returns the password of the elasticsearch auth.
*/}}
{{- define "nuxeo.secret.elasticsearch.auth.password" -}}
{{- if .Values.elasticsearch.auth.password -}}
{{- .Values.elasticsearch.auth.password -}}
{{- else -}}
{{- .Values.elasticsearch.basicAuth.password -}}
{{- end -}}
{{- end -}}

{{/*
Returns the name of the kafka secret to get auth from.
*/}}
{{- define "nuxeo.secret.kafka.name" -}}
{{- if .Values.kafka.auth.existingSecret -}}
{{- .Values.kafka.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-%s" (include "nuxeo.fullname" .) "kafka" -}}
{{- end -}}
{{- end -}}

{{/*
Returns the name of the Google Cloud Storage secret to get auth from.
*/}}
{{- define "nuxeo.secret.gcs.name" -}}
{{- if .Values.googleCloudStorage.auth.existingSecret -}}
{{- .Values.googleCloudStorage.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-%s" (include "nuxeo.fullname" .) "google-cloud-storage" -}}
{{- end -}}
{{- end -}}

{{/*
Returns the project id of the Google Cloud Storage auth.
*/}}
{{- define "nuxeo.secret.gcs.auth.projectId" -}}
{{- if .Values.googleCloudStorage.auth.projectId -}}
{{- .Values.googleCloudStorage.auth.projectId -}}
{{- else -}}
{{- .Values.googleCloudStorage.gcpProjectId -}}
{{- end -}}
{{- end -}}

{{/*
Returns the credentials of the Google Cloud Storage auth.
*/}}
{{- define "nuxeo.secret.gcs.auth.credentials" -}}
{{- if .Values.googleCloudStorage.auth.credentials -}}
{{- .Values.googleCloudStorage.auth.credentials -}}
{{- else -}}
{{- .Values.googleCloudStorage.credentials -}}
{{- end -}}
{{- end -}}

{{/*
Returns the name of the AmazonS3 secret to get auth from.
*/}}
{{- define "nuxeo.secret.amazonS3.name" -}}
{{- if .Values.amazonS3.auth.existingSecret -}}
{{- .Values.amazonS3.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-%s" (include "nuxeo.fullname" .) "amazon" -}}
{{- end -}}
{{- end -}}

{{/*
Returns the access key id of the AmazonS3 auth.
*/}}
{{- define "nuxeo.secret.amazonS3.auth.accessKeyId" -}}
{{- if .Values.amazonS3.auth.accessKeyId -}}
{{- .Values.amazonS3.auth.accessKeyId -}}
{{- else -}}
{{- .Values.amazonS3.accessKeyId -}}
{{- end -}}
{{- end -}}

{{/*
Returns the secret key of the AmazonS3 auth.
*/}}
{{- define "nuxeo.secret.amazonS3.auth.secretKey" -}}
{{- if .Values.amazonS3.auth.secretKey -}}
{{- .Values.amazonS3.auth.secretKey -}}
{{- else -}}
{{- .Values.amazonS3.secretAccessKey -}}
{{- end -}}
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

{{/*
Returns the name of the service account to use
*/}}
{{- define "nuxeo.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "nuxeo.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Return true if pod disruption budget is enabled.
*/}}
{{- define "nuxeo.poddisruptionbudget.enabled" -}}
{{- if or .Values.podDisruptionBudget.minAvailable .Values.podDisruptionBudget.maxUnavailable }}
  {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return true if Ingress TLS configuration is a list.
*/}}
{{- define "nuxeo.ingress.tls.list" -}}
{{- if kindIs "slice" .Values.ingress.tls -}}
  {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return true if Ingress TLS configuration is single, defined by its secret name.
*/}}
{{- define "nuxeo.ingress.tls.single" -}}
{{- if and (kindIs "map" .Values.ingress.tls) (.Values.ingress.tls.secretName) -}}
  {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Returns the URL bound to the Ingress host name.
*/}}
{{- define "nuxeo.ingress.url" -}}
{{- if and .Values.ingress.enabled .Values.ingress.hostname -}}
  {{- if or (include "nuxeo.ingress.tls.list" .) (include "nuxeo.ingress.tls.single" .) }}
    {{- printf "https://%s/" (.Values.ingress.hostname) -}}
  {{- else }}
    {{- printf "http://%s/" (.Values.ingress.hostname) -}}
  {{- end }}
{{- end -}}
{{- end -}}
