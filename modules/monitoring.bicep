// Copyright (c) 2026 Flowon Corp. Licensed under the MIT License.
// Derived from Azure-Samples/azmcp-obo-template, Copyright (c) Microsoft Corporation (MIT).

@description('Location for all resources')
param location string = resourceGroup().location

@description('Name for the Application Insights resource. The Log Analytics workspace is named "<name>-workspace".')
param name string

@description('Existing Application Insights connection string to reuse, "DISABLED" to turn telemetry off, or empty to create new resources.')
param appInsightsConnectionString string = ''

@description('Log Analytics retention in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Tags applied to every resource')
param tags object = {}

@description('Enable Azure Verified Modules usage telemetry')
param enableTelemetry bool = true

var shouldCreate = empty(appInsightsConnectionString)
var isDisabled = appInsightsConnectionString == 'DISABLED'

module workspace 'br/public:avm/res/operational-insights/workspace:0.16.1' = if (shouldCreate) {
  name: 'log-analytics-workspace'
  params: {
    name: '${name}-workspace'
    location: location
    dataRetention: retentionInDays
    tags: tags
    enableTelemetry: enableTelemetry
  }
}

module appInsights 'br/public:avm/res/insights/component:0.8.0' = if (shouldCreate) {
  name: 'application-insights'
  params: {
    name: name
    location: location
    workspaceResourceId: workspace!.outputs.resourceId
    retentionInDays: retentionInDays
    tags: tags
    enableTelemetry: enableTelemetry
  }
}

@description('Connection string to hand to the apps; empty when telemetry is disabled')
output connectionString string = shouldCreate
  ? appInsights!.outputs.connectionString
  : (isDisabled ? '' : appInsightsConnectionString)

@description('Name of the Log Analytics workspace created here, or empty when one was not created')
output logAnalyticsWorkspaceName string = shouldCreate ? workspace!.outputs.name : ''
