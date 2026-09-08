{{/*
Chart full name.
*/}}
{{- define "kyverno-policies.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels applied to every policy resource.
*/}}
{{- define "kyverno-policies.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/*
Render a match/exclude block from a rule spec.
Accepts a dict with:
  - .match   (list of {kinds, namespaces?, names?, selector?})
  - .exclude (list of {namespaces?, clusterRoles?})
*/}}
{{- define "kyverno-policies.matchExclude" -}}
match:
  any:
  {{- range .match }}
    - resources:
        kinds:
        {{- range .kinds }}
          - {{ . }}
        {{- end }}
        {{- if .namespaces }}
        namespaces:
        {{- range .namespaces }}
          - {{ . }}
        {{- end }}
        {{- end }}
        {{- if .names }}
        names:
        {{- range .names }}
          - {{ . | quote }}
        {{- end }}
        {{- end }}
        {{- if .selector }}
        selector:
          matchLabels:
            {{- toYaml .selector | nindent 12 }}
        {{- end }}
  {{- end }}
{{- if .exclude }}
exclude:
  any:
  {{- range .exclude }}
    {{- if or .namespaces .selector }}
    - resources:
        {{- if .namespaces }}
        namespaces:
        {{- range .namespaces }}
          - {{ . }}
        {{- end }}
        {{- end }}
        {{- if .selector }}
        selector:
          matchLabels:
            {{- toYaml .selector | nindent 12 }}
        {{- end }}
    {{- end }}
    {{- if .clusterRoles }}
    - clusterRoles:
      {{- range .clusterRoles }}
        - {{ . }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end -}}
