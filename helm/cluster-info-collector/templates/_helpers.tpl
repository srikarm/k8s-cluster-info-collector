{{/*
Expand the name of the chart.
*/}}
{{- define "cluster-info-collector.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "cluster-info-collector.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cluster-info-collector.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cluster-info-collector.labels" -}}
helm.sh/chart: {{ include "cluster-info-collector.chart" . }}
{{ include "cluster-info-collector.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cluster-info-collector.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cluster-info-collector.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Collector labels
*/}}
{{- define "cluster-info-collector.collector.labels" -}}
{{ include "cluster-info-collector.labels" . }}
app.kubernetes.io/component: collector
{{- end }}

{{/*
Collector selector labels
*/}}
{{- define "cluster-info-collector.collector.selectorLabels" -}}
{{ include "cluster-info-collector.selectorLabels" . }}
app.kubernetes.io/component: collector
{{- end }}

{{/*
Consumer labels
*/}}
{{- define "cluster-info-collector.consumer.labels" -}}
{{ include "cluster-info-collector.labels" . }}
app.kubernetes.io/component: consumer
{{- end }}

{{/*
Consumer selector labels
*/}}
{{- define "cluster-info-collector.consumer.selectorLabels" -}}
{{ include "cluster-info-collector.selectorLabels" . }}
app.kubernetes.io/component: consumer
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cluster-info-collector.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cluster-info-collector.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the collector image name
*/}}
{{- define "cluster-info-collector.image" -}}
{{- $registry := .Values.global.imageRegistry | default .Values.image.registry -}}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- else }}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- end }}
{{- end }}

{{/*
Create the consumer image name
*/}}
{{- define "cluster-info-collector.consumerImage" -}}
{{- $registry := .Values.global.imageRegistry | default .Values.consumerImage.registry -}}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry .Values.consumerImage.repository (.Values.consumerImage.tag | default .Chart.AppVersion) }}
{{- else }}
{{- printf "%s:%s" .Values.consumerImage.repository (.Values.consumerImage.tag | default .Chart.AppVersion) }}
{{- end }}
{{- end }}

{{/*
Generate Kafka brokers list
*/}}
{{- define "cluster-info-collector.kafkaBrokers" -}}
{{- if .Values.kafka.enabled }}
{{- printf "%s-kafka:9092" (include "cluster-info-collector.fullname" .) }}
{{- else }}
{{- .Values.externalKafka.brokers }}
{{- end }}
{{- end }}

{{/*
Generate PostgreSQL connection details
*/}}
{{- define "cluster-info-collector.postgresqlHost" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "%s-postgresql" (include "cluster-info-collector.fullname" .) }}
{{- else }}
{{- .Values.externalPostgresql.host }}
{{- end }}
{{- end }}

{{/*
Generate PostgreSQL port
*/}}
{{- define "cluster-info-collector.postgresqlPort" -}}
{{- if .Values.postgresql.enabled }}
{{- "5432" }}
{{- else }}
{{- .Values.externalPostgresql.port | toString }}
{{- end }}
{{- end }}

{{/*
Generate PostgreSQL database name
*/}}
{{- define "cluster-info-collector.postgresqlDatabase" -}}
{{- if .Values.postgresql.enabled }}
{{- .Values.postgresql.auth.database }}
{{- else }}
{{- .Values.externalPostgresql.database }}
{{- end }}
{{- end }}

{{/*
Generate PostgreSQL username
*/}}
{{- define "cluster-info-collector.postgresqlUsername" -}}
{{- if .Values.postgresql.enabled }}
{{- .Values.postgresql.auth.username }}
{{- else }}
{{- .Values.externalPostgresql.username }}
{{- end }}
{{- end }}

{{/*
Generate PostgreSQL password secret name
*/}}
{{- define "cluster-info-collector.postgresqlSecretName" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "%s-postgresql" (include "cluster-info-collector.fullname" .) }}
{{- else if .Values.externalPostgresql.existingSecret }}
{{- .Values.externalPostgresql.existingSecret }}
{{- else }}
{{- printf "%s-external-postgresql" (include "cluster-info-collector.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Generate PostgreSQL password secret key
*/}}
{{- define "cluster-info-collector.postgresqlPasswordKey" -}}
{{- if .Values.postgresql.enabled }}
{{- "postgres-password" }}
{{- else if .Values.externalPostgresql.existingSecret }}
{{- .Values.externalPostgresql.existingSecretPasswordKey }}
{{- else }}
{{- "password" }}
{{- end }}
{{- end }}

{{/*
Generate Kafka brokers secret name
*/}}
{{- define "cluster-info-collector.kafkaSecretName" -}}
{{- if .Values.kafka.enabled }}
{{- printf "%s-kafka" (include "cluster-info-collector.fullname" .) }}
{{- else if .Values.externalKafka.existingSecret }}
{{- .Values.externalKafka.existingSecret }}
{{- else }}
{{- printf "%s-external-kafka" (include "cluster-info-collector.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Generate Kafka brokers secret key
*/}}
{{- define "cluster-info-collector.kafkaBrokersKey" -}}
{{- if .Values.kafka.enabled }}
{{- "brokers" }}
{{- else if .Values.externalKafka.existingSecret }}
{{- .Values.externalKafka.existingSecretBrokersKey }}
{{- else }}
{{- "brokers" }}
{{- end }}
{{- end }}
