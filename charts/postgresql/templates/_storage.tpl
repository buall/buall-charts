{{/*
Copyright (c) 2026 middleware-charts contributors.
SPDX-License-Identifier: Apache-2.0
*/}}

{{/* vim: set filetype=mustache: */}}

{{/*
Return the effective StorageClass.
Persistence-specific configuration takes precedence over the global default.
An empty value lets Kubernetes choose its cluster default StorageClass.
*/}}
{{- define "postgresql.storageClass" -}}
{{- default .Values.global.storageClass .Values.persistence.storageClass -}}
{{- end -}}
