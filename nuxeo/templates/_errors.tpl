{{/* vim: set filetype=mustache: */}}

{{/*
Compile all errors into a single message, and call fail.
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
Validate clustering configuration: if more than 1 replica, must enable:
  - A cloud provider for binary storage.
  - A database.
  - Kafka or Redis.
*/}}
{{- define "nuxeo.validateValues.clustering" -}}
{{- if and (include "nuxeo.clustering.enabled" .) (not (and (or (include "nuxeo.binary.cloudProvider.enabled" .) (include "nuxeo.binary.pvc.has-many" .)) (include "nuxeo.database.enabled" .) (include "nuxeo.kafkaRedis.enabled" .))) -}}
{{-   printf "\n" -}}
nuxeo clustering configuration:

  When deploying a Nuxeo cluster, ie. replicaCount > 1 or architecture = api-worker, the following must be enabled:
    {{- if not (include "nuxeo.binary.cloudProvider.enabled" .) -}}
    {{-   printf "\n    " -}}
    - A cloud provider for binary storage. Please set either googleCloudStorage.enabled=true or amazonS3.enabled=true.
    {{- end -}}
    {{- if not (include "nuxeo.database.enabled" .) -}}
    {{-   printf "\n    " -}}
    - A database for metadata storage. Please set either mongodb.enabled=true or postgresql.enabled=true.
    {{- end -}}
    {{- if not (include "nuxeo.kafkaRedis.enabled" .) -}}
    {{-   printf "\n    " -}}
    - Kafka for the WorkManager, PubSub Service and Nuxeo Streams. Please set kafka.enabled=true.
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
