{{/*
Copyright (c) 2026 middleware-charts contributors.
SPDX-License-Identifier: Apache-2.0
*/}}

{{/* vim: set filetype=mustache: */}}

{{/*
Return an image reference, preferring a digest when one is configured.
The global registry is used only when the component still has its default
registry, matching the values contract for this chart.
*/}}
{{- define "postgresql.imageReference" -}}
{{- $registry := .image.registry -}}
{{- if and .globalRegistry (eq $registry .defaultRegistry) -}}
{{- $registry = .globalRegistry -}}
{{- end -}}
{{- if not $registry -}}
{{- $registry = .defaultRegistry -}}
{{- end -}}
{{- if .image.digest -}}
{{- printf "%s/%s@%s" $registry .image.repository .image.digest -}}
{{- else -}}
{{- printf "%s/%s:%s" $registry .image.repository .image.tag -}}
{{- end -}}
{{- end -}}

{{/*
Return the official PostgreSQL image reference.
*/}}
{{- define "postgresql.image" -}}
{{- include "postgresql.imageReference" (dict
  "image" .Values.image
  "globalRegistry" .Values.global.imageRegistry
  "defaultRegistry" "docker.io"
) -}}
{{- end -}}

{{/*
Return the postgres_exporter image reference.
*/}}
{{- define "postgresql.metricsImage" -}}
{{- include "postgresql.imageReference" (dict
  "image" .Values.metrics.image
  "globalRegistry" .Values.global.imageRegistry
  "defaultRegistry" "quay.io"
) -}}
{{- end -}}

{{/*
Return the volume-permissions init-container image reference.
*/}}
{{- define "postgresql.volumePermissionsImage" -}}
{{- include "postgresql.imageReference" (dict
  "image" .Values.volumePermissions.image
  "globalRegistry" .Values.global.imageRegistry
  "defaultRegistry" "docker.io"
) -}}
{{- end -}}

{{/*
Render image pull secrets, falling back to global.imagePullSecrets.
*/}}
{{- define "postgresql.imagePullSecrets" -}}
{{- $secrets := .Values.imagePullSecrets -}}
{{- if not $secrets -}}
{{- $secrets = .Values.global.imagePullSecrets -}}
{{- end -}}
{{- with $secrets -}}
{{- toYaml . -}}
{{- end -}}
{{- end -}}
