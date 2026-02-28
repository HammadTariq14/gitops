{{/*
Expand the name of the chart.
*/}}
{{- define "service.name" -}}
{{- if .Values.app.name }}
{{- .Values.app.name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "service.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Values.app.name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "service.labels" -}}
helm.sh/chart: {{ include "service.chart" . }}
{{ include "service.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- if .Values.app.version }}
app.kubernetes.io/app-version: {{ .Values.app.version | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ .Values.partOf | default "backend-platform" }}
app.kubernetes.io/component: {{ .Values.app.component | default "backend" }}
environment: {{ .Values.environment | default "development" }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- $baseName := printf "%s-sa" (include "service.fullname" .) -}}
{{- default $baseName .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Active service name (for blue/green traffic switching)
Usage: {{ include "service.activeServiceName" . }}
*/}}
{{- define "service.activeServiceName" -}}
{{- if .Values.blueGreen.enabled -}}
{{- printf "%s-svc-active" (include "service.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-svc" (include "service.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{/*
============================================
LOOP-FRIENDLY HELPERS FOR BLUE-GREEN
These helpers work within range loops where context changes
============================================
*/}}

{{/*
Generate versioned resource name for use in loops
Usage: {{ include "service.versionedNameForColor" (dict "root" $ "color" $color) }}
*/}}
{{- define "service.versionedNameForColor" -}}
{{- $baseName := include "service.fullname" .root -}}
{{- printf "%s-%s" $baseName .color | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Generate ConfigMap name for specific color
Usage: {{ include "service.configMapNameForColor" (dict "root" $ "color" $color) }}
*/}}
{{- define "service.configMapNameForColor" -}}
{{- $baseName := printf "%s-config" (include "service.fullname" .root) -}}
{{- if .root.Values.blueGreen.enabled -}}
{{- printf "%s-%s" $baseName .color | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $baseName | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{/*
Generate Secret name for specific color
Usage: {{ include "service.secretNameForColor" (dict "root" $ "color" $color) }}
*/}}
{{- define "service.secretNameForColor" -}}
{{- $baseName := printf "%s-secret" (include "service.fullname" .root) -}}
{{- if .root.Values.blueGreen.enabled -}}
{{- printf "%s-%s" $baseName .color | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $baseName | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{/*
Generate SecretProviderClass name for specific color
Usage: {{ include "service.secretProviderClassNameForColor" (dict "root" $ "color" $color) }}
*/}}
{{- define "service.secretProviderClassNameForColor" -}}
{{- $baseName := printf "%s-spc" (include "service.fullname" .root) -}}
{{- if .root.Values.blueGreen.enabled -}}
{{- printf "%s-%s" $baseName .color | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $baseName | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{/*
Get color configuration from loop context
Usage: {{ include "service.colorConfig" (dict "root" $ "color" $color) }}
*/}}
{{- define "service.colorConfig" -}}
{{- index .root.Values.blueGreen.colors .color -}}
{{- end }}

{{/*
Get image tag for specific color with fallback to global
Usage: {{ include "service.imageTagForColor" (dict "root" $ "color" $color "config" $config) }}
*/}}
{{- define "service.imageTagForColor" -}}
{{- .config.imageTag | default .root.Values.image.tag | default .root.Chart.AppVersion -}}
{{- end }}

{{/*
Check if color is the production slot
Usage: {{ if include "service.isProductionSlot" (dict "root" $ "color" $color) }}
*/}}
{{- define "service.isProductionSlot" -}}
{{- if eq .root.Values.blueGreen.productionSlot .color -}}
true
{{- end -}}
{{- end }}

{{/*
============================================
KEYVAULT HELPERS
============================================
*/}}

{{/*
Resolve Key Vault secret name with override support
Usage: {{ include "service.keyVaultSecretName" (dict "secretKey" "JWT_SECRET" "defaultName" "jwt-secret-prod" "context" .) }}
*/}}
{{- define "service.keyVaultSecretName" -}}
{{- $secretKey := .secretKey -}}
{{- $defaultName := .defaultName -}}
{{- $context := .context -}}
{{- if $context.Values.keyVault.secretOverrides -}}
{{- $override := index $context.Values.keyVault.secretOverrides $secretKey -}}
{{- if $override -}}
{{- $override -}}
{{- else -}}
{{- $defaultName -}}
{{- end -}}
{{- else -}}
{{- $defaultName -}}
{{- end -}}
{{- end }}

{{/*
Check if Key Vault is enabled and configured
Usage: {{ if include "service.isKeyVaultEnabled" . }}
*/}}
{{- define "service.isKeyVaultEnabled" -}}
{{- if and .Values.keyVault.enabled .Values.keyVault.name .Values.keyVault.clientId .Values.keyVault.tenantId -}}
true
{{- end -}}
{{- end }}

{{/*
============================================
ANNOTATION HELPERS
============================================
*/}}

{{/*
Generate environment-specific annotations
Usage: {{ include "service.environmentAnnotations" . | nindent 4 }}
*/}}
{{- define "service.environmentAnnotations" -}}
deployment.kubernetes.io/environment: {{ .Values.environment | default "development" }}
{{- if .Values.blueGreen.enabled }}
deployment.kubernetes.io/strategy: "blue-green"
{{- else }}
deployment.kubernetes.io/strategy: "rolling-update"
{{- end }}
{{- if include "service.isKeyVaultEnabled" . }}
secrets.kubernetes.io/source: "azure-key-vault"
secrets.kubernetes.io/vault: {{ .Values.keyVault.name | quote }}
{{- else }}
secrets.kubernetes.io/source: "kubernetes-secret"
{{- end }}
{{- end }}

{{/*
Generate annotations for specific color deployment
Usage: {{ include "service.deploymentAnnotationsForColor" (dict "root" $ "color" $color "config" $config) | nindent 4 }}
*/}}
{{- define "service.deploymentAnnotationsForColor" -}}
deployment.kubernetes.io/color: {{ .color | quote }}
deployment.kubernetes.io/revision: {{ include "service.imageTagForColor" . | quote }}
{{- if include "service.isProductionSlot" (dict "root" .root "color" .color) }}
deployment.kubernetes.io/production: "true"
{{- else }}
deployment.kubernetes.io/production: "false"
{{- end }}
{{- end }}

{{/*
============================================
VALIDATION HELPERS
============================================
*/}}

{{/*
Validate required values
Usage: {{ include "service.validateValues" . }}
*/}}
{{- define "service.validateValues" -}}
{{- if not .Values.app -}}
  {{- fail "app configuration is required in values" -}}
{{- end -}}
{{- if not .Values.app.name -}}
  {{- fail "app.name is required in values" -}}
{{- end -}}
{{- if .Values.blueGreen.enabled -}}
  {{/* Validate productionSlot */}}
  {{- if not .Values.blueGreen.productionSlot -}}
    {{- fail "blueGreen.productionSlot is required when blueGreen.enabled is true" -}}
  {{- end -}}
  {{- if not (or (eq .Values.blueGreen.productionSlot "blue") (eq .Values.blueGreen.productionSlot "green")) -}}
    {{- fail "blueGreen.productionSlot must be either 'blue' or 'green'" -}}
  {{- end -}}
  
  {{/* Validate productionSlot color is enabled */}}
  {{- $productionColor := .Values.blueGreen.productionSlot -}}
  {{- $productionConfig := index .Values.blueGreen.colors $productionColor -}}
  {{- if not $productionConfig -}}
    {{- fail (printf "blueGreen.productionSlot '%s' must exist in colors configuration" $productionColor) -}}
  {{- end -}}
  {{- if not $productionConfig.enabled -}}
    {{- fail (printf "blueGreen.productionSlot '%s' must be enabled in colors configuration" $productionColor) -}}
  {{- end -}}
  
  {{/* Validate colors configuration */}}
  {{- if not .Values.blueGreen.colors -}}
    {{- fail "blueGreen.colors configuration is required when blueGreen.enabled is true" -}}
  {{- end -}}
  {{- $hasEnabledColor := false -}}
  {{- $hasImageTag := true -}}
  {{- range $color, $config := .Values.blueGreen.colors -}}
    {{- if $config.enabled -}}
      {{- $hasEnabledColor = true -}}
      {{/* Validate each enabled color has imageTag */}}
      {{- if not $config.imageTag -}}
        {{- if not $.Values.image.tag -}}
          {{- fail (printf "Color '%s' must specify imageTag when enabled (no global image.tag fallback found)" $color) -}}
        {{- end -}}
      {{- end -}}
      {{/* Validate image tag is not latest or empty */}}
      {{- $imageTag := $config.imageTag | default $.Values.image.tag -}}
      {{- if or (eq $imageTag "") (eq $imageTag "latest") -}}
        {{- fail (printf "Color '%s' cannot use empty or 'latest' tag in production. Current tag: '%s'" $color $imageTag) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  {{- if not $hasEnabledColor -}}
    {{- fail "At least one color must be enabled in blueGreen.colors when blueGreen.enabled is true" -}}
  {{- end -}}
  
  {{/* Validate activeColor if staging is enabled */}}
  {{- if .Values.ingress.test.enabled -}}
    {{- if .Values.blueGreen.activeColor -}}
      {{- if not (or (eq .Values.blueGreen.activeColor "blue") (eq .Values.blueGreen.activeColor "green")) -}}
        {{- fail "blueGreen.activeColor must be either 'blue' or 'green'" -}}
      {{- end -}}
      {{/* Validate activeColor references an enabled color */}}
      {{- $activeConfig := index .Values.blueGreen.colors .Values.blueGreen.activeColor -}}
      {{- if $activeConfig -}}
        {{- if not $activeConfig.enabled -}}
          {{- fail (printf "blueGreen.activeColor '%s' must be enabled when staging ingress is enabled" .Values.blueGreen.activeColor) -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if .Values.keyVault.enabled -}}
  {{- if not .Values.keyVault.name -}}
    {{- fail "keyVault.name is required when keyVault.enabled is true" -}}
  {{- end -}}
  {{- if not .Values.keyVault.clientId -}}
    {{- fail "keyVault.clientId is required when keyVault.enabled is true" -}}
  {{- end -}}
  {{- if not .Values.keyVault.tenantId -}}
    {{- fail "keyVault.tenantId is required when keyVault.enabled is true" -}}
  {{- end -}}
{{- end -}}
{{/* Validate workload identity configuration */}}
{{- if .Values.serviceAccount.workloadIdentity.enabled -}}
  {{- if not .Values.serviceAccount.workloadIdentity.clientId -}}
    {{- fail "serviceAccount.workloadIdentity.clientId is required when workloadIdentity is enabled" -}}
  {{- end -}}
  {{- if not .Values.serviceAccount.workloadIdentity.tenantId -}}
    {{- fail "serviceAccount.workloadIdentity.tenantId is required when workloadIdentity is enabled" -}}
  {{- end -}}
{{- end -}}
{{/* Validate image tag for non-blue-green deployments */}}
{{- if not .Values.blueGreen.enabled -}}
  {{- if and .Values.image.tag (or (eq .Values.image.tag "") (eq .Values.image.tag "latest")) -}}
    {{- if eq .Values.environment "production" -}}
      {{- fail "Cannot use empty or 'latest' tag in production environment" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{/* Validate Gateway API configuration */}}
{{- if .Values.gatewayApi.enabled -}}
  {{- if not .Values.gatewayApi.parentRefs -}}
    {{- fail "gatewayApi.parentRefs is required when gatewayApi.enabled is true" -}}
  {{- end -}}
  {{- if not .Values.gatewayApi.hostnames -}}
    {{- fail "gatewayApi.hostnames is required when gatewayApi.enabled is true" -}}
  {{- end -}}
  {{- if and .Values.gatewayApi.test.enabled (not .Values.blueGreen.enabled) -}}
    {{- fail "gatewayApi.test.enabled requires blueGreen.enabled to be true" -}}
  {{- end -}}
  {{- if and .Values.gatewayApi.test.enabled (not .Values.gatewayApi.test.hostnames) -}}
    {{- fail "gatewayApi.test.hostnames is required when gatewayApi.test.enabled is true" -}}
  {{- end -}}
{{- end -}}
{{- end }}