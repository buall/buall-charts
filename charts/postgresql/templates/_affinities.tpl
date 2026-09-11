{{/*
Copyright (c) 2026 middleware-charts contributors.
SPDX-License-Identifier: Apache-2.0
*/}}

{{/* vim: set filetype=mustache: */}}

{{/*
Render the pod affinity settings selected by the values API.
Custom affinity is used when no preset is selected. When presets are used,
anti-affinity takes precedence if both presets are configured, preserving the
chart's existing behavior.
*/}}
{{- define "postgresql.affinity" -}}
{{- if and .Values.affinity (not (or .Values.podAffinityPreset .Values.podAntiAffinityPreset)) -}}
{{- toYaml .Values.affinity -}}
{{- else if or .Values.podAffinityPreset .Values.podAntiAffinityPreset -}}
{{- $matchLabels := include "postgresql.selectorLabels" . | fromYaml -}}
{{- $labelSelector := dict "matchLabels" $matchLabels -}}
{{- $podAffinityTerm := dict
  "topologyKey" "kubernetes.io/hostname"
  "labelSelector" $labelSelector
-}}
{{- if .Values.podAntiAffinityPreset -}}
{{- if eq .Values.podAntiAffinityPreset "hard" -}}
{{- toYaml (dict "podAntiAffinity" (dict
  "requiredDuringSchedulingIgnoredDuringExecution" (list $podAffinityTerm)
)) -}}
{{- else -}}
{{- $preferredTerm := dict "weight" 100 "podAffinityTerm" $podAffinityTerm -}}
{{- toYaml (dict "podAntiAffinity" (dict
  "preferredDuringSchedulingIgnoredDuringExecution" (list $preferredTerm)
)) -}}
{{- end -}}
{{- else -}}
{{- $preferredTerm := dict "weight" 100 "podAffinityTerm" $podAffinityTerm -}}
{{- toYaml (dict "podAffinity" (dict
  "preferredDuringSchedulingIgnoredDuringExecution" (list $preferredTerm)
)) -}}
{{- end -}}
{{- end -}}
{{- end -}}
