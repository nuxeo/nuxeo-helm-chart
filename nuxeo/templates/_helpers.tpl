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
  labels: {{- include "nuxeo.labels" . | nindent 4 }}
type: Opaque
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
{{- if .Values.postgresql.existingSecret -}}
{{- .Values.postgresql.existingSecret -}}
{{- else -}}
{{- printf "%s-%s" (include "nuxeo.fullname" .) "postgresql" -}}
{{- end -}}
{{- end -}}

{{/*
Returns the name of the elasticsearch secret to get auth from.
*/}}
{{- define "nuxeo.secret.elasticsearch.name" -}}
{{- if .Values.elasticsearch.basicAuth.existingSecret -}}
{{- .Values.elasticsearch.basicAuth.existingSecret -}}
{{- else -}}
{{- printf "%s-%s" (include "nuxeo.fullname" .) "elasticsearch" -}}
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
Returns the name of the Google Cloud Platform secret to get auth from.
*/}}
{{- define "nuxeo.secret.gcp.name" -}}
{{- if .Values.googleCloudStorage.existingSecret -}}
{{- .Values.googleCloudStorage.existingSecret -}}
{{- else -}}
{{- printf "%s-%s" (include "nuxeo.fullname" .) "google-cloud" -}}
{{- end -}}
{{- end -}}

{{/*
Returns the name of the Amazon secret to get auth from.
*/}}
{{- define "nuxeo.secret.amazon.name" -}}
{{- if .Values.amazonS3.existingSecret -}}
{{- .Values.amazonS3.existingSecret -}}
{{- else -}}
{{- printf "%s-%s" (include "nuxeo.fullname" .) "amazon" -}}
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
