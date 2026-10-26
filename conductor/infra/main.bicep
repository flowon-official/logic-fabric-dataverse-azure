// Copyright (c) 2026 Flowon Corp. Licensed under the MIT License.
// Derived from Azure-Samples/azmcp-obo-template, Copyright (c) Microsoft Corporation (MIT).

metadata name = 'Flowon Logic Fabric Conductor'
metadata description = 'Deploys the Logic Fabric Conductor MCP server to Azure Container Apps, with its Entra app registrations and Dataverse Application User.'

import { containerSizingType, logLevelType, networkingType } from '../../modules/types.bicep'

// ----------------------------------------------------------------------------------------------
// General
// ----------------------------------------------------------------------------------------------

@description('Location for all resources')
param location string = resourceGroup().location

@description('Prefix for resource names: lowercase letters, digits and hyphens, starting with a letter. The app is named <prefix>-conductor.')
@minLength(2)
@maxLength(22)
param namePrefix string = 'logic-fabric'

@description('Prefix for Entra app registration display names')
param displayNamePrefix string = 'Flowon Logic Fabric'

@description('Tags applied to every Azure resource')
param tags object = {}

@description('Enable Azure Verified Modules usage telemetry')
param enableTelemetry bool = true

// ----------------------------------------------------------------------------------------------
// Image
// ----------------------------------------------------------------------------------------------

@description('Registry and namespace the image is pulled from. Must allow anonymous pulls.')
param imageRegistry string = 'docker.io/flowon'

@description('Conductor image tag')
param imageTag string = '1.0.0'

// ----------------------------------------------------------------------------------------------
// Dataverse and Entra
// ----------------------------------------------------------------------------------------------

@description('URL of the Dataverse environment Conductor connects to, e.g. https://your-org.crm.dynamics.com/')
param dataverseUrl string

@description('Comma- or semicolon-separated Flowon project names whose artifacts with "Expose as MCP Tool" turned on become tools. If empty, Conductor exposes no tools.')
param flowonProjects string = ''

@description('ID of the Dataverse security role assigned to Conductor\'s managed identity. Defaults to Logic Fabric Author, shipped in the LogicFabricComposer solution.')
param dataverseSecurityRoleId string = '9c714d77-f19f-ee11-baeb-00155d007237'

@description('Resource ID of an existing user-assigned managed identity with System Administrator in the Dataverse environment. It registers Conductor\'s identity as a Dataverse Application User. Create one with scripts/New-DataverseSetupIdentity.ps1.')
param setupManagedIdentityId string

@description('Grant tenant-wide admin consent for Conductor\'s Dataverse permission. Needs Global Administrator or Privileged Role Administrator; set to false and grant consent in the portal otherwise.')
param grantAdminConsent bool = true

@description('App ID of an existing dev/CLI client app to reuse. If empty, one is created.')
param entraAppClientId string = ''

@description('Optional Service Management Reference GUID for the Entra apps')
param serviceManagementReference string = ''

// ----------------------------------------------------------------------------------------------
// Runtime
// ----------------------------------------------------------------------------------------------

@description('Application Insights connection string to reuse, "DISABLED" to turn telemetry off, or empty to create new resources')
param appInsightsConnectionString string = ''

@description('Minimum log level')
param logLevel logLevelType = 'Warning'

@description('Container size and scale. Defaults: 0.25 vCPU, 0.5Gi, 1-3 replicas.')
param sizing containerSizingType = {}

@description('Optional custom domain, e.g. conductor.contoso.com')
param customDomain string = ''

@description('IPv4 addresses or CIDR ranges allowed to reach Conductor. Empty allows all.')
param allowedIpRanges string[] = []

@description('Optional virtual network integration for the Container Apps environment')
param network networkingType?

var uniqueSuffix = uniqueString(resourceGroup().id)
var appName = '${namePrefix}-conductor'
var entraAppClientDisplayName = '${displayNamePrefix} Conductor MCP Client'
var entraAppServerDisplayName = '${displayNamePrefix} Conductor MCP Server'

module monitoring '../../modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    name: '${appName}-insights'
    location: location
    appInsightsConnectionString: appInsightsConnectionString
    tags: tags
    enableTelemetry: enableTelemetry
  }
}

module containerAppsEnvironment '../../modules/container-apps-environment.bicep' = {
  name: 'container-apps-environment'
  params: {
    name: '${appName}-env'
    location: location
    tags: tags
    customDomains: [customDomain]
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    network: network
  }
}

module managedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.6.0' = {
  name: 'conductor-identity'
  params: {
    name: '${appName}-identity'
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
  }
}

module entraAppClient '../../modules/entra-client-app.bicep' = {
  name: 'entra-conductor-client'
  params: {
    entraAppDisplayName: entraAppClientDisplayName
    entraAppUniqueName: '${replace(toLower(entraAppClientDisplayName), ' ', '-')}-${uniqueSuffix}'
    entraAppId: entraAppClientId
    serviceManagementReference: serviceManagementReference
  }
}

module entraAppServer '../../modules/entra-server-app.bicep' = {
  name: 'entra-conductor-server'
  params: {
    entraAppDisplayName: entraAppServerDisplayName
    entraAppUniqueName: '${replace(toLower(entraAppServerDisplayName), ' ', '-')}-${uniqueSuffix}'
    entraAppScopeValue: 'Mcp.Tools.ReadWrite'
    entraAppScopeDisplayName: '${displayNamePrefix} Conductor MCP ReadWrite'
    entraAppScopeDescription: 'Allow calling apps to call ${displayNamePrefix} Conductor MCP tools on behalf of the signed-in user'
    knownClientAppId: entraAppClient.outputs.entraAppClientId
    acaManagedIdentityObjectId: managedIdentity.outputs.principalId
    grantAdminConsent: grantAdminConsent
    serviceManagementReference: serviceManagementReference
  }
}

module dataverseApplicationUser '../../modules/dataverse-application-user.bicep' = {
  name: 'dataverse-application-user'
  params: {
    name: '${appName}-dataverse-setup'
    location: location
    tags: tags
    dataverseUrl: dataverseUrl
    applicationClientId: managedIdentity.outputs.clientId
    securityRoleId: dataverseSecurityRoleId
    identityId: setupManagedIdentityId
  }
}

var telemetryEnabled = !empty(monitoring.outputs.connectionString)

module containerApp '../../modules/container-app.bicep' = {
  name: 'conductor-container-app'
  params: {
    location: location
    containerAppName: appName
    environmentId: containerAppsEnvironment.outputs.id
    image: '${imageRegistry}/logic-fabric-dataverse-conductor:${imageTag}'
    userAssignedManagedIdentityId: managedIdentity.outputs.resourceId
    customDomain: customDomain
    certificateId: !empty(customDomain) ? containerAppsEnvironment.outputs.certificateIds[0].certificateId : ''
    sizing: union({ cpuCores: '0.25', memorySize: '0.5Gi' }, sizing)
    allowedIpRanges: allowedIpRanges
    tags: tags
    env: concat(
      [
        { name: 'ASPNETCORE_ENVIRONMENT', value: 'Production' }
        { name: 'ASPNETCORE_URLS', value: 'http://+:8080' }
        { name: 'MCP_SERVER_TRANSPORT_TYPE', value: 'Http' }
        { name: 'DATAVERSE__AUTHENTICATION_STRATEGY', value: 'OnBehalfOf' }
        { name: 'DATAVERSE__URL', value: dataverseUrl }
        { name: 'DATAVERSE__SCOPES', value: '${dataverseUrl}.default' }
        // Startup tool discovery connects as the managed identity; per-request calls stay on-behalf-of.
        { name: 'DATAVERSE__MANAGED_IDENTITY_CLIENT_ID', value: managedIdentity.outputs.clientId }
        { name: 'COLLECT_TELEMETRY', value: string(telemetryEnabled) }
        { name: 'AzureAd__Instance', value: environment().authentication.loginEndpoint }
        { name: 'AzureAd__TenantId', value: tenant().tenantId }
        { name: 'AzureAd__ClientId', value: entraAppServer.outputs.entraAppClientId }
        { name: 'AzureAd__ClientCredentials__0__SourceType', value: 'SignedAssertionFromManagedIdentity' }
        { name: 'AzureAd__ClientCredentials__0__ManagedIdentityClientId', value: managedIdentity.outputs.clientId }
        { name: 'LOG_LEVEL', value: logLevel }
      ],
      !empty(flowonProjects) ? [{ name: 'ProjectNames', value: flowonProjects }] : [],
      telemetryEnabled
        ? [{ name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: monitoring.outputs.connectionString }]
        : []
    )
  }
}

output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = resourceGroup().name

output CONDUCTOR_CONTAINER_APP_NAME string = containerApp.outputs.containerAppName
output CONDUCTOR_URL string = containerApp.outputs.containerAppUrl
output CONDUCTOR_CUSTOM_DOMAIN_URL string = containerApp.outputs.customDomainUrl
output CONDUCTOR_MANAGED_IDENTITY_CLIENT_ID string = managedIdentity.outputs.clientId
output CONDUCTOR_SERVER_APP_ID string = entraAppServer.outputs.entraAppClientId
output CONDUCTOR_SCOPE string = 'api://${entraAppServer.outputs.entraAppClientId}/${entraAppServer.outputs.entraAppScopeValue}'
output CONDUCTOR_CLIENT_APP_ID string = entraAppClient.outputs.entraAppClientId
output DATAVERSE_APPLICATION_USER_ID string = dataverseApplicationUser.outputs.systemUserId

output CONTAINER_APPS_ENVIRONMENT_ID string = containerAppsEnvironment.outputs.id
output CUSTOM_DOMAIN_VERIFICATION_ID string = containerAppsEnvironment.outputs.customDomainVerificationId
output APPLICATION_INSIGHTS_CONNECTION_STRING string = monitoring.outputs.connectionString
