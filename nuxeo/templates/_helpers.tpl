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
*/}}
{{- define "nuxeo.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- printf .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Compile all warnings into a single message, and call fail.
*/}}
{{- define "nuxeo.validateValues" -}}
{{- $messages := list -}}
{{- $messages := append $messages (include "nuxeo.validateValues.database" .) -}}
{{- $messages := append $messages (include "nuxeo.validateValues.kafkaRedis" .) -}}
{{- $messages := without $messages "" -}}
{{- $message := join "\n" $messages -}}

{{- if $message -}}
{{-   printf "\n\nVALUES VALIDATION:\n%s" $message | fail -}}
{{- end -}}
{{- end -}}

{{/* Validate database configuration: can enable either MongoDB or PostgreSQL but not both . */}}
{{- define "nuxeo.validateValues.database" -}}
{{- if and .Values.nuxeo.mongodb.enabled .Values.nuxeo.postgresql.enabled -}}
 {{-   printf "\n" -}}
 nuxeo database configuration:

  MongoDB and PostgreSQL databases cannot be enabled at the same time.
  Please set either nuxeo.mongodb.enabled=true or nuxeo.postgresql.enabled=true.
{{- end -}}
{{- end -}}

{{/* Validate Kafka/Redis mutual exclusion: can enable either kafka or Redis but not both . */}}
{{- define "nuxeo.validateValues.kafkaRedis" -}}
{{- if and .Values.nuxeo.kafka.enabled .Values.nuxeo.redis.enabled -}}
 {{-   printf "\n" -}}
 kafka and redis mutual exclusion:

  Kafka and Redis cannot be enabled at the same time.
  Please set either nuxeo.kafka.enabled=true or nuxeo.redis.enabled=true.
{{- end -}}
{{- end -}}