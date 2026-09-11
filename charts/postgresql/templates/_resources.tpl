{{/*
Copyright (c) 2026 middleware-charts contributors.
SPDX-License-Identifier: Apache-2.0
*/}}

{{/* vim: set filetype=mustache: */}}

{{/*
Return resource requests and limits for a named preset.
Explicit resources always take precedence over the preset. Presets are meant
for development and basic testing; production workloads should set resources
directly.
*/}}
{{- define "postgresql.resources" -}}
{{- if .resources -}}
{{- toYaml .resources -}}
{{- else -}}
{{- $preset := default "none" .preset -}}
{{- $presets := dict
  "none" (dict)
  "nano" (dict
    "requests" (dict "cpu" "50m" "memory" "64Mi")
    "limits" (dict "cpu" "250m" "memory" "256Mi")
  )
  "micro" (dict
    "requests" (dict "cpu" "100m" "memory" "128Mi")
    "limits" (dict "cpu" "500m" "memory" "512Mi")
  )
  "small" (dict
    "requests" (dict "cpu" "250m" "memory" "256Mi")
    "limits" (dict "cpu" "1" "memory" "1Gi")
  )
  "medium" (dict
    "requests" (dict "cpu" "500m" "memory" "512Mi")
    "limits" (dict "cpu" "2" "memory" "2Gi")
  )
  "large" (dict
    "requests" (dict "cpu" "1" "memory" "1Gi")
    "limits" (dict "cpu" "4" "memory" "4Gi")
  )
  "xlarge" (dict
    "requests" (dict "cpu" "2" "memory" "2Gi")
    "limits" (dict "cpu" "8" "memory" "8Gi")
  )
  "2xlarge" (dict
    "requests" (dict "cpu" "4" "memory" "4Gi")
    "limits" (dict "cpu" "16" "memory" "16Gi")
  )
-}}
{{- if hasKey $presets $preset -}}
{{- index $presets $preset | toYaml -}}
{{- else -}}
{{- printf "unsupported resources preset %q" $preset | fail -}}
{{- end -}}
{{- end -}}
{{- end -}}
