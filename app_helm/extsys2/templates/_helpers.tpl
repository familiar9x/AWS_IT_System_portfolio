{{- define "common.labels" -}}
app.kubernetes.io/name: {{ include "chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "chart.name" -}}
{{ default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end -}}
