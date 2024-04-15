{{/*
Create a app name.
*/}}
{{- define "myapp.fullname" -}}
{{- $baseName := default "" .Values.app.name -}}
{{- $version := default "" .Values.appconfig.VERSION -}}
{{- $nameParts := list $baseName -}}
{{- if and $version (ne $version "") -}}
  {{- $nameParts = append $nameParts $version -}}
{{- end -}}
{{- join "-" $nameParts | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{/*
Create a release name.
*/}}
{{- define "app.releaseName" -}}
{{- $baseName := default "" .Values.deploy.baseName -}}
{{- $version := default "" .Values.appconfig.VERSION -}}
{{- $nameParts := list $baseName -}}
{{- if and $version (ne $version "") -}}
  {{- $nameParts = append $nameParts $version -}}
{{- end -}}
{{- join "-" $nameParts | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Generate the standard labels used by the chart.
*/}}
{{- define "myapp.labels" -}}
app.kubernetes.io/name: {{ .Values.app.name }}
app.kubernetes.io/component: {{ .Values.app.component }}
app.kubernetes.io/part-of: {{ .Values.app.partOf }}
app.kubernetes.io/instance: {{ include "app.releaseName" . }}
app.kubernetes.io/version: {{ default "v1" .Values.appconfig.VERSION }}
app.kubernetes.io/managed-by: Helm
{{- end -}}

{{/*
Generate the standard labels used by the chart.
*/}}
{{- define "mysql.labels" -}}
app.kubernetes.io/name: {{ .Values.db.name }}
app.kubernetes.io/component: {{ .Values.db.component }}
app.kubernetes.io/part-of: {{ .Values.db.partOf }}
app.kubernetes.io/managed-by: Helm
{{- end -}}

{{/*
Generate configmap data for hash calculation.
*/}}
{{- define "myapp.configmapdata" -}}
data:
  VERSION: {{ .Values.appconfig.VERSION }}
  GROUP_NAME: {{ .Values.appconfig.GROUP_NAME }}
  GROUP_SLOGAN: {{ .Values.appconfig.GROUP_SLOGAN }}
  S3_IMAGE_URL: {{ .Values.appconfig.S3_IMAGE_URL }}
  GROUP_IMAGE: {{ .Values.appconfig.GROUP_IMAGE }}
{{- end -}}
