{{/*
Copyright (c) 2026 middleware-charts contributors.
SPDX-License-Identifier: Apache-2.0
*/}}

{{/* vim: set filetype=mustache: */}}

{{/*
Return the shared preload libraries requested explicitly or implied by the
supported extensions. repmgr is intentionally not implied: it is installed
and created as an extension, but it is not a PostgreSQL preload library.
*/}}
{{- define "postgresql.sharedPreloadLibraries" -}}
{{- $libraries := list -}}
{{- range .Values.postgresql.sharedPreloadLibraries }}
{{- $libraries = append $libraries . -}}
{{- end }}
{{- $preloadExtensions := dict "timescaledb" true "pgaudit" true "pg_cron" true -}}
{{- range .Values.postgresql.extensions }}
{{- if and (hasKey $preloadExtensions .) (not (has . $libraries)) }}
{{- $libraries = append $libraries . -}}
{{- end }}
{{- end }}
{{- join "," (uniq $libraries) -}}
{{- end }}

{{/*
Return the database used by pg_cron. The explicit chart value is useful when
credentials come from an existing Secret, because the Secret contents are not
available during normal offline Helm rendering.
*/}}
{{- define "postgresql.cronDatabaseName" -}}
{{- default .Values.auth.database .Values.postgresql.cronDatabaseName -}}
{{- end }}

{{/*
Generate the pg_cron database setting when pg_cron is requested. An explicit
cron.database_name line in postgresql.configuration takes precedence in the
configuration template.
*/}}
{{- define "postgresql.generatedCronDatabaseConfiguration" -}}
{{- $database := include "postgresql.cronDatabaseName" . | trim -}}
{{- if and (has "pg_cron" .Values.postgresql.extensions) (ne $database "") }}
{{- printf "cron.database_name = '%s'" (replace "'" "''" $database) -}}
{{- end }}
{{- end }}

{{/*
Generate idempotent CREATE EXTENSION statements. Names are schema-validated as
SQL identifiers, so quoting them keeps generated SQL safe and predictable.
*/}}
{{- define "postgresql.extensionInitScript" -}}
{{- range .Values.postgresql.extensions }}
CREATE EXTENSION IF NOT EXISTS {{ . | quote }};
{{- end }}
{{- end }}
