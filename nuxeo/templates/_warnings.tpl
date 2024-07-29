{{/* vim: set filetype=mustache: */}}

{{- define "nuxeo.warnings.message" -}}
{{- $messages := list -}}
{{- $messages := append $messages (include "nuxeo.warnings.message.binary.cloudProvider" .) -}}
{{- $messages := append $messages (include "nuxeo.warnings.message.binary.pvc" .) -}}
{{- $messages := append $messages (include "nuxeo.warnings.message.ingress.sticky-session" .) -}}
{{- $messages := append $messages (include "nuxeo.warnings.message.log.pvc" .) -}}
{{- $messages := append $messages (include "nuxeo.warnings.message.rolling-tag" .) -}}
{{- $messages := without $messages "" -}}
{{- $message := join "\n\n" $messages -}}

{{- if $message -}}
{{- printf "\n" }}
{{- printf "\n" }}
-------------------------------------------------------------------------------
WARNING
{{ $message }}
{{- printf "\n" }}
-------------------------------------------------------------------------------
{{- end -}}
{{- end -}}

{{- define "nuxeo.warnings.message.binary.cloudProvider" -}}
{{- if not (include "nuxeo.binary.cloudProvider.enabled" .) }}
  Using a cloud provider for binary storage is preferred for production.
  You can enable one by setting either:
    googleCloudStorage.enabled=true or amazonS3.enabled=true.
  {{- if not (.Values.persistentVolumeStorage.enabled) }}
  By not enabling a persistent volume for binary storage, binaries will be
  stored in an emptyDir volume, thus not surviving a pod restart.
  {{- end }}
{{- end -}}
{{- end -}}

{{- define "nuxeo.warnings.message.binary.pvc" -}}
{{- if .Values.persistentVolumeStorage.enabled -}}
  {{- if include "nuxeo.binary.pvc.has-many" . }}
  Enabling a persistent volume for binary storage with the ReadWriteMany
  access mode is not supported by the Nuxeo Helm Chart.
  Additional configuration might need to be added,
  see https://doc.nuxeo.com/nxdoc/file-storage-architecture/.
  {{- else }}
  By enabling a persistent volume for binary storage, since it is mounted
  with the ReadWriteOnce access mode, the deployment won't be able
  to scale up in Kubernetes.
  {{- end }}
{{- end -}}
{{- end -}}

{{- define "nuxeo.warnings.message.ingress.sticky-session" -}}
{{- if and (.Values.ingress.enabled) (include "nuxeo.clustering.enabled" .) }}
  Nuxeo needs sticky session for cookie to work correctly. Unfortunately
  this can not be achieved by the Nuxeo Helm Chart as it depends on your
  Ingress controller, see below some examples:
  * NGINX - add the annotation below to the ingress:
      ingress:
        annotations:
          nginx.ingress.kubernetes.io/affinity: "cookie"
  * Traefik - add the annotation below to the service:
      service:
        annotations:
          traefik.ingress.kubernetes.io/service.sticky.cookie: "true"
{{- end -}}
{{- end -}}

{{- define "nuxeo.warnings.message.log.pvc" -}}
{{- if .Values.logs.persistence.enabled -}}
  {{- if include "nuxeo.log.pvc.has-many" . }}
  Enabling a persistent volume for logs storage with the ReadWriteMany
  access mode is not supported by the Nuxeo Helm Chart.
  Additional configuration might need to be added, otherwise every Nuxeo
  pods will write to the same server.log.
  {{- else }}
  By enabling a persistent volume for log storage, since it is mounted with
  the ReadWriteOnce access mode, the deployment won't be able to scale up
  in Kubernetes.
  {{- end }}
  It is not recommended for production, a log collector is preferred.
{{- end -}}
{{- end -}}

{{- define "nuxeo.warnings.message.rolling-tag" -}}
{{- if and (contains "/nuxeo/nuxeo" .Values.image.repository) (not (.Values.image.tag | toString | regexFind "^(\\d){4}\\.(\\d)+.*$" )) }}
  Rolling tag detected ({{ .Values.image.repository }}:{{ .Values.image.tag }}),
  please note that it is strongly recommended to avoid using rolling tags
  in a production environment.
{{- end -}}
{{- end -}}
