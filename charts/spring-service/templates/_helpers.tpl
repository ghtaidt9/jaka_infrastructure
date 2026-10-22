{{- define "spring-service.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}