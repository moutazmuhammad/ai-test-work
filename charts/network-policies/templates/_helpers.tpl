{{/*
Generate podSelector labels if the netpol applied to specific Pod.
*/}}
{{- define "netpol.podSelector" }}
{{- if .podSelector }}
podSelector:
  {{- range $key, $value := .podSelector }}
  matchLabels:
    {{ $key }}: {{ $value }}
  {{- end }}
{{- else }}
podSelector: {}
{{- end }}
{{- end }}

{{/*
Ingress block
*/}}
{{- define "netpol.ingress" }}
ingress:
- from:
  {{- if .ingress.cidrs }}
    {{- with .ingress }}
    {{- include "netpol.scoped.cidr" (dict "scope" .) | indent 2 }}
    {{- end }}
  {{- end }}

  {{- if .ingress.podSelectors }}
    {{- with .ingress }}
    {{- include "netpol.scoped.podSelector" (dict "scope" .) | indent 2 }}
    {{- end }}
  {{- end }}

  {{- if .ingress.namespaceSelectors }}
    {{- with .ingress }}
    {{- include "netpol.scoped.namespaceSelector" (dict "scope" .) | indent 2 }}
    {{- end }}
  {{- end }}

  {{- if .ingress.ports }}
    {{- with .ingress }}
    {{- include "netpol.scoped.port" (dict "scope" .) | indent 2 }}
    {{- end }}
  {{- end }}
{{- end }}

{{/*
Egress block
*/}}
{{- define "netpol.egress" }}
egress:
- to:
  {{- if .egress.cidrs }}
    {{- with .egress }}
    {{- include "netpol.scoped.cidr" (dict "scope" .) | indent 2 }}
    {{- end }}
  {{- end }}

  {{- if .egress.podSelectors }}
    {{- with .egress }}
    {{- include "netpol.scoped.podSelector" (dict "scope" .) | indent 2 }}
    {{- end }}
  {{- end }}

  {{- if .egress.namespaceSelectors }}
    {{- with .egress }}
    {{- include "netpol.scoped.namespaceSelector" (dict "scope" .) | indent 2 }}
    {{- end }}
  {{- end }}

  {{- if .egress.ports }}
    {{- with .egress }}
    {{- include "netpol.scoped.port" (dict "scope" .) | indent 2 }}
    {{- end }}
  {{- end }}
{{- end }}

{{/*
Generate netpol by IP Block CIDR
*/}}
{{- define "netpol.scoped.cidr" }}
{{- range .scope.cidrs }}
- ipBlock:
    cidr: {{ .ip }}
    {{- if .excepts }}
    except: {{ toYaml .excepts | nindent 6 }}
    {{- end }}
{{- end }}
{{- end }}

{{/*
Generate netpol by Pod selector 
*/}}

{{- define "netpol.scoped.podSelector" }}
{{- range .scope.podSelectors }}
{{- $labelYaml := toYaml .label }}
{{- if contains ":" $labelYaml }}
- podSelector:
    matchLabels: {{ toYaml .label | nindent 6 }}
    {{- if .matches }}
    {{- include "netpol.matcher" . | indent 4 }}
    {{- end }}
{{- else }}
- podSelector: {}
{{- end }}
{{- end }}
{{- end }}

{{/*
Generate netpol by Namespace selector 
*/}}

{{- define "netpol.scoped.namespaceSelector" }}
{{- range .scope.namespaceSelectors }}
{{- $labelYaml := toYaml .label }}
{{- if contains ":" $labelYaml }}
- namespaceSelector:
    matchLabels: {{ toYaml .label | nindent 6 }}
    {{- if .matches }}
    {{- include "netpol.matcher" . | indent 4 }}
    {{- end }}
  {{- range .podSelectors }}
  podSelector:
    matchLabels: {{ toYaml .label | nindent 6 }}
    {{- if .matches }}
    {{- include "netpol.matcher" . | indent 4 }}
    {{- end }}
  {{- end }}
{{- else }}
- namespaceSelector: {}
  {{- range .podSelectors }}
  podSelector:
    matchLabels: {{ toYaml .label | nindent 6 }}
    {{- if .matches }}
    {{- include "netpol.matcher" . | indent 4 }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}


{{/*
Generate matcher expression label
*/}}

{{- define "netpol.matcher" }}
matchExpressions:
{{- range .matches }}
{{- if hasKey . "matchIn" }}
- operator: In
  {{- range $key, $val := .matchIn }}
  key: {{ $key }}
  values: {{ toYaml $val | nindent 2 }}
  {{- end }}
{{- end }}

{{- if hasKey . "matchNotIn" }}
- operator: NotIn
  {{- range $key, $val := .matchNotIn }}
  key: {{ $key }}
  values: {{ toYaml $val | nindent 2 }}
  {{- end }}
{{- end }}

{{- if hasKey . "matchExists" }}
- operator: Exists
  key: {{ .matchExists }}
{{- end }}

{{- if hasKey . "matchNotExist" }}
- operator: DoesNotExist
  key: {{ .matchNotExist }}
{{- end }}

{{- end }}
{{- end }}

{{/*
Generate ports list
*/}}

{{- define "netpol.scoped.port" }}
ports:
{{- with .scope.ports }}
{{- if .tcp  }}
{{- range .tcp }}
- protocol: TCP
  port: {{ . }}
{{- end }}
{{- end }}

{{- if .udp }}
{{- range .udp }}
- protocol: UDP
  port: {{ . }}
{{- end }}
{{- end }}

{{- end }}
{{- end }}