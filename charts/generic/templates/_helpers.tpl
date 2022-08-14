{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 24 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "appname" -}}
{{- $releaseName := default .Release.Name .Values.releaseOverride -}}
{{- printf "%s" $releaseName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "imagename" -}}
{{- if eq .Values.image.tag "" -}}
{{- .Values.image.repository -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}
{{- end -}}

{{- define "trackableappname" -}}
{{- $trackableName := printf "%s-%s" (include "appname" .) .Values.application.track -}}
{{- $trackableName | trimSuffix "-stable" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Get a hostname from URL
*/}}
{{- define "hostname" -}}
{{- . | trimPrefix "http://" |  trimPrefix "https://" | trimSuffix "/" | trim | quote -}}
{{- end -}}

{{/*
Get SecRule's arguments with unescaped single&double quotes
*/}}
{{- define "secrule" -}}
{{- $operator := .operator | quote | replace "\"" "\\\"" | replace "'" "\\'" -}}
{{- $action := .action | quote | replace "\"" "\\\"" | replace "'" "\\'" -}}
{{- printf "SecRule %s %s %s" .variable $operator $action -}}
{{- end -}}

{{/*
Generate a name for a Persistent Volume Claim
*/}}
{{- define "pvcName" -}}
{{- printf "%s-%s" (include "fullname" .context) .name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "sharedlabels" -}}
app: {{ template "appname" . }}
chart: "{{ .Chart.Name }}-{{ .Chart.Version| replace "+" "_" }}"
release: {{ .Release.Name }}
heritage: {{ .Release.Service }}
app.kubernetes.io/name: {{ template "appname" . }}
helm.sh/chart: "{{ .Chart.Name }}-{{ .Chart.Version| replace "+" "_" }}"
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Values.extraLabels }}
{{ toYaml $.Values.extraLabels }}
{{- end }}
{{- end -}}

{{- define "ingress.annotations" -}}
{{- $defaults := include (print $.Template.BasePath "/_ingress-annotations.yaml") . | fromYaml -}}
{{- $custom := .Values.ingress.annotations | default dict -}}
{{- $merged := deepCopy $custom | mergeOverwrite $defaults -}}
{{- $merged | toYaml -}}
{{- end -}}


{{- define "env" -}}
env:
  {{- range .Values.env }}
  -
{{ toYaml . | indent 4 }}
  {{- end -}}
  {{- if .Values.postgresql.managed }}
  - name: POSTGRES_USER
    valueFrom:
      secretKeyRef:
        name: app-postgres
        key: username
  - name: POSTGRES_PASSWORD
    valueFrom:
      secretKeyRef:
        name: app-postgres
        key: password
  - name: POSTGRES_HOST
    valueFrom:
      secretKeyRef:
        name: app-postgres
        key: privateIP
  {{- end }}
  {{- if .Values.application.database_url }}
  - name: DATABASE_URL
    value: {{ .Values.application.database_url | quote }}
  {{- end }}
  - name: GITLAB_ENVIRONMENT_NAME
    value: {{ .Values.gitlab.envName | quote }}
  - name: GITLAB_ENVIRONMENT_URL
    value: {{ .Values.gitlab.envURL | quote }}
{{- end -}}

{{- define "volumesCM" -}}
- name: custom-settings
  configMap:
    name: {{ include "fullname" . }}-cm
{{- end -}}

{{- define "mountCM" -}}
{{ range $key, $value := .Values.mountConfigmap }}
- name: custom-settings
  mountPath: {{ $value }}
  subPath: {{ $key }}
  readOnly: true
{{ end }}
{{- end -}}

{{- define "volumes" }}
volumes:
{{ include "volumesCM" . | indent 2 }}
{{- if .Values.persistence.enabled }}
{{- $context := . }}
{{- range $volume := .Values.persistence.volumes }}
  - name: {{ $volume.name | quote }}
    persistentVolumeClaim:
      {{ $args := dict "context" $context "name" $volume.name }}
      claimName: {{ template "pvcName" $args }}
{{- end }}
{{- end }}

{{- end -}}

{{- define "volumesMount" }}
volumeMounts:
{{ include "mountCM" . | indent 2 }}
{{- if .Values.persistence.enabled }}
{{- range $volume := .Values.persistence.volumes }}
  - name: {{ $volume.name | quote }}
    mountPath: {{ $volume.mount.path | quote }}
    {{- if $volume.mount.subPath }}
    subPath: {{ $volume.mount.subPath | quote }}
    {{- end }}
{{- end }}
{{- end }}

{{- end -}}