{{/*
Copyright (c) 2026 middleware-charts contributors.
SPDX-License-Identifier: Apache-2.0
*/}}

{{/* vim: set filetype=mustache: */}}

{{/*
Return labels shared by all PostgreSQL resources.
Values in commonLabels override a generated label with the same key.
*/}}
{{- define "postgresql.labels" -}}
{{- $labels := dict
  "helm.sh/chart" (include "postgresql.chart" .)
  "app.kubernetes.io/name" (include "postgresql.name" .)
  "app.kubernetes.io/instance" .Release.Name
  "app.kubernetes.io/managed-by" .Release.Service
  "app.kubernetes.io/version" .Chart.AppVersion
-}}
{{- range $key, $value := .Values.commonLabels -}}
{{- $_ := set $labels $key $value -}}
{{- end -}}
{{- toYaml $labels -}}
{{- end -}}

{{/*
Return the stable selector labels used by Services and the StatefulSet.
*/}}
{{- define "postgresql.selectorLabels" -}}
app.kubernetes.io/name: {{ include "postgresql.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
