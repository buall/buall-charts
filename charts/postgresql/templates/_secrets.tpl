{{/*
Copyright (c) 2026 middleware-charts contributors.
SPDX-License-Identifier: Apache-2.0
*/}}

{{/* vim: set filetype=mustache: */}}

{{/*
Return the Secret name used by PostgreSQL credentials.
*/}}
{{- define "postgresql.auth.secretName" -}}
{{- default (include "postgresql.fullname" .) .Values.auth.existingSecret -}}
{{- end -}}

{{/*
Return the key containing the PostgreSQL username.
*/}}
{{- define "postgresql.auth.usernameKey" -}}
{{- default "username" .Values.auth.secretKeys.usernameKey -}}
{{- end -}}

{{/*
Return the key containing the PostgreSQL password.
*/}}
{{- define "postgresql.auth.passwordKey" -}}
{{- default "password" .Values.auth.secretKeys.passwordKey -}}
{{- end -}}

{{/*
Return the key containing the PostgreSQL database name.
*/}}
{{- define "postgresql.auth.databaseKey" -}}
{{- default "database" .Values.auth.secretKeys.databaseKey -}}
{{- end -}}
