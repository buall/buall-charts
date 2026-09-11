{{/*
Copyright (c) 2026 middleware-charts contributors.
SPDX-License-Identifier: Apache-2.0
*/}}

{{/* vim: set filetype=mustache: */}}

{{/*
Return the native PostgreSQL readiness command used by all probes.
*/}}
{{- define "postgresql.probeCommand" -}}
- sh
- -c
- >-
  pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" -h 127.0.0.1 -p 5432
{{- end -}}
