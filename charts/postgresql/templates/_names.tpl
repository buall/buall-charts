{{/*
Copyright (c) 2026 middleware-charts contributors.
SPDX-License-Identifier: Apache-2.0
*/}}

{{/* vim: set filetype=mustache: */}}

{{/*
Return the chart name.
*/}}
{{- define "postgresql.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the fully qualified name used by PostgreSQL resources.
*/}}
{{- define "postgresql.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "postgresql.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Return the chart name and version label value.
*/}}
{{- define "postgresql.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the ServiceAccount name used by the PostgreSQL pod.
*/}}
{{- define "postgresql.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "postgresql.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Return the headless Service name used by the StatefulSet.
*/}}
{{- define "postgresql.headlessServiceName" -}}
{{- printf "%s-headless" (include "postgresql.fullname" .) -}}
{{- end -}}

{{/*
Return the names of the ConfigMaps mounted by the PostgreSQL pod.
*/}}
{{- define "postgresql.initdbScriptsConfigMapName" -}}
{{- printf "%s-initdb" (include "postgresql.fullname" .) -}}
{{- end -}}

{{- define "postgresql.configurationConfigMapName" -}}
{{- printf "%s-config" (include "postgresql.fullname" .) -}}
{{- end -}}

{{/*
Return the name of the optional metrics Service.
*/}}
{{- define "postgresql.metricsServiceName" -}}
{{- printf "%s-metrics" (include "postgresql.fullname" .) -}}
{{- end -}}
