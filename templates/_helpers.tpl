{{- define "pinniped-supervisor.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "pinniped-supervisor.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "pinniped-supervisor.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "pinniped-supervisor.labels" -}}
{{ include "pinniped-supervisor.selectorLabels" . }}
helm.sh/chart: {{ include "pinniped-supervisor.chart" . }}
app.kubernetes.io/name: {{ include "pinniped-supervisor.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "pinniped-supervisor.selectorLabels" -}}
app: pinniped-supervisor
{{- end -}}

{{- define "pinniped-supervisor.deploymentSelectorLabels" -}}
deployment.pinniped.dev: supervisor
{{- end -}}

{{- define "pinniped-supervisor.podLabels" -}}
{{ include "pinniped-supervisor.selectorLabels" . }}
{{ include "pinniped-supervisor.deploymentSelectorLabels" . }}
{{- end -}}

{{- define "pinniped-supervisor.serviceAccountName" -}}
{{- .Values.serviceAccount.supervisor.name | default (include "pinniped-supervisor.fullname" .) -}}
{{- end -}}

{{- define "pinniped-supervisor.image" -}}
{{- $tag := .Values.image.tag | default (printf "v%s" .Chart.AppVersion) -}}
{{- if .Values.image.digest -}}
{{- printf "%s:%s@%s" .Values.image.repository $tag .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}
{{- end -}}

{{- define "pinniped-supervisor.verifyExistingSecret" -}}
{{- $secret := lookup "v1" "Secret" .root.Release.Namespace .name -}}
{{- if $secret -}}
{{- if ne $secret.type .type -}}
{{- fail (printf "%s: existing Secret %q must be of type %q, got %q" .path .name .type $secret.type) -}}
{{- end -}}
{{- range .keys -}}
{{- if not (hasKey (dig "data" dict $secret) .) -}}
{{- fail (printf "%s: existing Secret %q is missing key %q" $.path $.name .) -}}
{{- end -}}
{{- end -}}
{{- else if lookup "v1" "Namespace" "" "kube-system" -}}
{{- fail (printf "%s: existing Secret %q not found in namespace %q" .path .name .root.Release.Namespace) -}}
{{- end -}}
{{- end -}}
