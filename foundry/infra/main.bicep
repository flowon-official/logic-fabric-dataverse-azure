// Copyright (c) 2026 Flowon Corp. Licensed under the MIT License.
// Derived from Azure-Samples/azmcp-obo-template, Copyright (c) Microsoft Corporation (MIT).
//
// Deployment order: environment → managed identities → agent Entra apps (their SPA redirect URIs
// need the environment's default domain) → Foundry server app (pre-authorizes every agent) →
// Foundry Container App → agent Container Apps (need Foundry's URL and scope).

metadata name = 'Flowon Logic Fabric Foundry and agents'
metadata description = 'Deploys the Foundry MCP server and the Logic Fabric agents to Azure Container Apps, with the Entra app registrations for the on-behalf-of chain between them.'

import { containerSizingType, logLevelType, networkingType } from '../../modules/types.bicep'

type agentKeyType = 'assist' | 'assurance' | 'context' | 'guard' | 'insight' | 'sentinel'

@sealed()
type perAgentStringType = {
  assist: string?
  assurance: string?
  context: string?
  guard: string?
  insight: string?
  sentinel: string?
}

@sealed()
type imageTagOverridesType = {
  foundry: string?
  assist: string?
  assurance: string?
  context: string?
  guard: string?
  insight: string?
  sentinel: string?
}

// ----------------------------------------------------------------------------------------------
// General
// ----------------------------------------------------------------------------------------------

@description('Location for all resources')
param location string = resourceGroup().location

@description('Prefix for resource names: lowercase letters, digits and hyphens, starting with a letter. Apps are named <prefix>-foundry, <prefix>-assist, etc.')
@minLength(2)
@maxLength(22)
param namePrefix string = 'logic-fabric'

@description('Prefix for Entra app registration display names')
param displayNamePrefix string = 'Flowon Logic Fabric'

@description('Tags applied to every Azure resource')
param tags object = {}

@description('Agents to deploy')
param enabledAgents agentKeyType[] = [
  'assist'
  'assurance'
  'context'
  'guard'
  'insight'
  'sentinel'
]

@description('Enable Azure Verified Modules usage telemetry')
param enableTelemetry bool = true

// ----------------------------------------------------------------------------------------------
// Images
// ----------------------------------------------------------------------------------------------

@description('Registry and namespace the images are pulled from. Must allow anonymous pulls.')
param imageRegistry string = 'docker.io/flowon'

@description('Image tag for Foundry and every agent')
param imageTag string = '1.0.0'

@description('Per-image tag overrides, e.g. { assist: \'1.0.1\' }')
param imageTagOverrides imageTagOverridesType = {}

// ----------------------------------------------------------------------------------------------
// Dataverse and Entra
// ----------------------------------------------------------------------------------------------

@description('URL of the Dataverse environment Foundry connects to, e.g. https://your-org.crm.dynamics.com/')
param dataverseUrl string

@description('ID of the Dataverse security role assigned to Foundry\'s managed identity. Defaults to Logic Fabric Author, shipped in the LogicFabricComposer solution.')
param dataverseSecurityRoleId string = '9c714d77-f19f-ee11-baeb-00155d007237'

@description('Resource ID of an existing user-assigned managed identity with System Administrator in the Dataverse environment. It registers Foundry\'s identity as a Dataverse Application User. Create one with scripts/New-DataverseSetupIdentity.ps1.')
param setupManagedIdentityId string

@description('Grant tenant-wide admin consent for Foundry\'s Dataverse permission. Needs Global Administrator or Privileged Role Administrator; set to false and grant consent in the portal otherwise.')
param grantAdminConsent bool = true

@description('App ID of an existing Foundry dev/CLI client app to reuse. If empty, one is created.')
param entraAppClientId string = ''

@description('App IDs of existing agent apps to reuse instead of creating new ones, keyed by agent')
param agentEntraAppIds perAgentStringType = {}

@description('Optional Service Management Reference GUID for the Entra apps')
param serviceManagementReference string = ''

// ----------------------------------------------------------------------------------------------
// LLM provider: only the parameters for the selected llmProvider are used
// ----------------------------------------------------------------------------------------------

@description('LLM provider the agents use')
@allowed([
  'AzureFoundryAnthropic'
  'AzureFoundry'
  'AzureFoundryOpenAI'
  'OpenAI'
  'Anthropic'
])
param llmProvider string = 'AzureFoundryAnthropic'

@description('Maximum concurrent LLM requests per agent')
param llmMaxConcurrency int = 4

@description('AzureFoundryAnthropic: endpoint, e.g. https://<resource>.services.ai.azure.com/anthropic')
param azureFoundryAnthropicEndpoint string = ''

@secure()
@description('AzureFoundryAnthropic: API key')
param azureFoundryAnthropicApiKey string = ''

@description('AzureFoundryAnthropic: model deployment name')
param azureFoundryAnthropicModel string = ''

@description('AzureFoundryAnthropic: request timeout in minutes')
param azureFoundryAnthropicTimeoutMinutes int = 10

@description('AzureFoundryAnthropic: maximum output tokens')
param azureFoundryAnthropicMaxOutputTokens int = 16384

@description('AzureFoundryAnthropic: Anthropic API version')
param azureFoundryAnthropicVersion string = '2023-06-01'

@description('AzureFoundry: Azure AI Inference endpoint, e.g. https://<resource>.services.ai.azure.com/models')
param azureFoundryEndpoint string = ''

@secure()
@description('AzureFoundry: API key')
param azureFoundryApiKey string = ''

@description('AzureFoundry: model name')
param azureFoundryModel string = ''

@description('AzureFoundryOpenAI: endpoint, e.g. https://<resource>.openai.azure.com/')
param azureFoundryOpenAIEndpoint string = ''

@secure()
@description('AzureFoundryOpenAI: API key')
param azureFoundryOpenAIApiKey string = ''

@description('AzureFoundryOpenAI: deployment name')
param azureFoundryOpenAIModel string = ''

@secure()
@description('OpenAI: API key')
param openAIApiKey string = ''

@description('OpenAI: model name')
param openAIModel string = ''

@secure()
@description('Anthropic: API key')
param anthropicApiKey string = ''

@description('Anthropic: model name')
param anthropicModel string = ''

@description('Anthropic: request timeout in minutes')
param anthropicTimeoutMinutes int = 10

@description('Anthropic: maximum output tokens')
param anthropicMaxOutputTokens int = 16384

@description('Anthropic: API version')
param anthropicVersion string = '2023-06-01'

// ----------------------------------------------------------------------------------------------
// Runtime
// ----------------------------------------------------------------------------------------------

@description('Application Insights connection string to reuse, "DISABLED" to turn telemetry off, or empty to create new resources')
param appInsightsConnectionString string = ''

@description('Minimum log level for Foundry and the agents')
param logLevel logLevelType = 'Warning'

@description('Foundry container size and scale')
param foundrySizing containerSizingType = {}

@description('Container size and scale for every agent')
param agentSizing containerSizingType = {}

@description('Optional custom domain for Foundry, e.g. foundry.contoso.com')
param foundryCustomDomain string = ''

@description('Optional custom domains keyed by agent, e.g. { guard: \'guard.contoso.com\' }. Each is also added as a sign-in redirect URI on that agent\'s Entra app.')
param agentCustomDomains perAgentStringType = {}

@description('IPv4 addresses or CIDR ranges allowed to reach Foundry and the agents. Empty allows all. Agent web apps are used from browsers, so include your users\' ranges.')
param allowedIpRanges string[] = []

@description('Optional virtual network integration for the Container Apps environment')
param network networkingType?

@secure()
@description('Connection string for an existing Redis (e.g. Azure Managed Redis) in StackExchange.Redis format. When set, the internal Redis and its storage are not deployed.')
param externalRedisConnectionString string = ''

// azd generates this on the first provision (only for parameters without a default) and keeps it
// in the environment, so later provisions reuse it. Alphanumeric only: ',' and '=' are separators
// in the Redis connection string.
@secure()
@minLength(16)
@description('Password for the internal Redis, alphanumeric. Unused, but still required, when externalRedisConnectionString is set.')
@metadata({
  azd: {
    type: 'generate'
    config: {
      length: 32
      noSpecial: true
    }
  }
})
param redisPassword string

// ----------------------------------------------------------------------------------------------
// Names and per-agent settings
// ----------------------------------------------------------------------------------------------

var uniqueSuffix = uniqueString(resourceGroup().id)
var foundryAppName = '${namePrefix}-foundry'
var foundryScopeValue = 'Mcp.Tools.ReadWrite'
var useInternalRedis = empty(externalRedisConnectionString)
var redisAppName = '${namePrefix}-redis'

// StackExchange.Redis format. keepAlive stops idle connections being silently dropped by the
// environment's proxy.
var redisConnectionString = useInternalRedis
  ? '${redisAppName}:6379,password=${redisPassword},ssl=False,abortConnect=False,connectTimeout=5000,syncTimeout=5000,connectRetry=3,keepAlive=60'
  : externalRedisConnectionString

var agents = [
  for key in filter(['assist', 'assurance', 'context', 'guard', 'insight', 'sentinel'], k => contains(enabledAgents, k)): {
    key: key
    containerAppName: '${namePrefix}-${key}'
    entraAppDisplayName: '${displayNamePrefix} ${toUpper(substring(key, 0, 1))}${substring(key, 1)} Agent'
    entraAppUniqueName: '${replace(toLower('${displayNamePrefix} ${key} agent'), ' ', '-')}-${uniqueSuffix}'
    existingEntraAppId: agentEntraAppIds[?key] ?? ''
    customDomain: agentCustomDomains[?key] ?? ''
    image: '${imageRegistry}/logic-fabric-dataverse-${key}:${imageTagOverrides[?key] ?? imageTag}'
  }
]

// Non-secret LLM settings per provider; only the selected provider's entry is applied.
var llmEnvByProvider = {
  AzureFoundryAnthropic: [
    { name: 'AZURE_FOUNDRY_ANTHROPIC_ENDPOINT', value: azureFoundryAnthropicEndpoint }
    { name: 'AZURE_FOUNDRY_ANTHROPIC_MODEL', value: azureFoundryAnthropicModel }
    { name: 'AZURE_FOUNDRY_ANTHROPIC_TIMEOUT_MINUTES', value: string(azureFoundryAnthropicTimeoutMinutes) }
    { name: 'AZURE_FOUNDRY_ANTHROPIC_MAX_OUTPUT_TOKENS', value: string(azureFoundryAnthropicMaxOutputTokens) }
    { name: 'AZURE_FOUNDRY_ANTHROPIC_VERSION', value: azureFoundryAnthropicVersion }
  ]
  AzureFoundry: [
    { name: 'AZURE_FOUNDRY_ENDPOINT', value: azureFoundryEndpoint }
    { name: 'AZURE_FOUNDRY_MODEL', value: azureFoundryModel }
  ]
  AzureFoundryOpenAI: [
    { name: 'AZURE_FOUNDRY_OPENAI_ENDPOINT', value: azureFoundryOpenAIEndpoint }
    { name: 'AZURE_FOUNDRY_OPENAI_MODEL', value: azureFoundryOpenAIModel }
  ]
  OpenAI: [
    { name: 'OPENAI_MODEL', value: openAIModel }
  ]
  Anthropic: [
    { name: 'ANTHROPIC_MODEL', value: anthropicModel }
    { name: 'ANTHROPIC_TIMEOUT_MINUTES', value: string(anthropicTimeoutMinutes) }
    { name: 'ANTHROPIC_MAX_OUTPUT_TOKENS', value: string(anthropicMaxOutputTokens) }
    { name: 'ANTHROPIC_VERSION', value: anthropicVersion }
  ]
}

// The agent images read AzureFoundryOpenAI as 'AzureOpenAI'.
var llmProviderEnvValue = llmProvider == 'AzureFoundryOpenAI' ? 'AzureOpenAI' : llmProvider

var llmApiKeyEnvNameByProvider = {
  AzureFoundryAnthropic: 'AZURE_FOUNDRY_ANTHROPIC_API_KEY'
  AzureFoundry: 'AZURE_FOUNDRY_API_KEY'
  AzureFoundryOpenAI: 'AZURE_FOUNDRY_OPENAI_API_KEY'
  OpenAI: 'OPENAI_API_KEY'
  Anthropic: 'ANTHROPIC_API_KEY'
}

var selectedLlmApiKey = {
  AzureFoundryAnthropic: azureFoundryAnthropicApiKey
  AzureFoundry: azureFoundryApiKey
  AzureFoundryOpenAI: azureFoundryOpenAIApiKey
  OpenAI: openAIApiKey
  Anthropic: anthropicApiKey
}[llmProvider]

// ----------------------------------------------------------------------------------------------
// Shared infrastructure
// ----------------------------------------------------------------------------------------------

module monitoring '../../modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    name: '${namePrefix}-foundry-insights'
    location: location
    appInsightsConnectionString: appInsightsConnectionString
    tags: tags
    enableTelemetry: enableTelemetry
  }
}

module redisStorage 'br/public:avm/res/storage/storage-account:0.33.1' = if (useInternalRedis) {
  name: 'redis-storage'
  params: {
    name: 'redis${uniqueSuffix}'
    location: location
    tags: tags
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    // Container Apps mounts Azure Files with the account key.
    allowSharedKeyAccess: true
    fileServices: {
      shares: [
        {
          name: 'redis-data'
          shareQuota: 5
        }
      ]
    }
    enableTelemetry: enableTelemetry
  }
}

module containerAppsEnvironment '../../modules/container-apps-environment.bicep' = {
  name: 'container-apps-environment'
  params: {
    name: '${namePrefix}-foundry-env'
    location: location
    tags: tags
    customDomains: concat([foundryCustomDomain], map(agents, agent => agent.customDomain))
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    network: network
    redisStorageAccountName: useInternalRedis ? redisStorage!.outputs.name : ''
    redisFileShareName: useInternalRedis ? 'redis-data' : ''
  }
}

var certificateIdsByDomain = toObject(
  containerAppsEnvironment.outputs.certificateIds,
  c => c.domain,
  c => c.certificateId
)

module redis '../../modules/redis.bicep' = if (useInternalRedis) {
  name: 'redis'
  params: {
    location: location
    containerAppName: redisAppName
    environmentId: containerAppsEnvironment.outputs.id
    environmentStorageName: containerAppsEnvironment.outputs.redisStorageName
    redisPassword: redisPassword
    tags: tags
  }
}

// One managed identity per app, so each federated credential trusts only its own app.
module foundryManagedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.6.0' = {
  name: 'foundry-identity'
  params: {
    name: '${foundryAppName}-identity'
    location: location
    tags: tags
    enableTelemetry: enableTelemetry
  }
}

module agentManagedIdentities 'br/public:avm/res/managed-identity/user-assigned-identity:0.6.0' = [
  for agent in agents: {
    name: '${agent.key}-identity'
    params: {
      name: '${agent.containerAppName}-identity'
      location: location
      tags: tags
      enableTelemetry: enableTelemetry
    }
  }
]

// ----------------------------------------------------------------------------------------------
// Entra app registrations
// ----------------------------------------------------------------------------------------------

var entraAppClientDisplayName = '${displayNamePrefix} Foundry MCP Client'
var entraAppServerDisplayName = '${displayNamePrefix} Foundry MCP Server'

module entraAppClient '../../modules/entra-client-app.bicep' = {
  name: 'entra-foundry-client'
  params: {
    entraAppDisplayName: entraAppClientDisplayName
    entraAppUniqueName: '${replace(toLower(entraAppClientDisplayName), ' ', '-')}-${uniqueSuffix}'
    entraAppId: entraAppClientId
    serviceManagementReference: serviceManagementReference
  }
}

module agentEntraApps '../../modules/entra-agent-app.bicep' = [
  for (agent, i) in agents: {
    name: 'entra-${agent.key}'
    params: {
      entraAppDisplayName: agent.entraAppDisplayName
      entraAppUniqueName: agent.entraAppUniqueName
      entraAppId: agent.existingEntraAppId
      spaRedirectUris: concat(
        ['https://${agent.containerAppName}.${containerAppsEnvironment.outputs.defaultDomain}'],
        !empty(agent.customDomain) ? ['https://${agent.customDomain}'] : []
      )
      acaManagedIdentityObjectId: agentManagedIdentities[i].outputs.principalId
      serviceManagementReference: serviceManagementReference
    }
  }
]

module entraAppServer '../../modules/entra-server-app.bicep' = {
  name: 'entra-foundry-server'
  params: {
    entraAppDisplayName: entraAppServerDisplayName
    entraAppUniqueName: '${replace(toLower(entraAppServerDisplayName), ' ', '-')}-${uniqueSuffix}'
    entraAppScopeValue: foundryScopeValue
    entraAppScopeDisplayName: '${displayNamePrefix} Foundry MCP ReadWrite'
    entraAppScopeDescription: 'Allow calling apps to read and write ${displayNamePrefix} Foundry MCP tools on behalf of the signed-in user'
    knownClientAppId: entraAppClient.outputs.entraAppClientId
    additionalKnownClientAppIds: [for (agent, i) in agents: agentEntraApps[i].outputs.entraAppClientId]
    acaManagedIdentityObjectId: foundryManagedIdentity.outputs.principalId
    grantAdminConsent: grantAdminConsent
    serviceManagementReference: serviceManagementReference
  }
}

// Skipped for reused agent apps: their real scope ID is unknown, so patching them would be wrong.
module agentEntraAppPermissions '../../modules/entra-agent-grant-permissions.bicep' = [
  for (agent, i) in agents: if (empty(agent.existingEntraAppId)) {
    name: 'entra-${agent.key}-permissions'
    params: {
      entraAppUniqueName: agent.entraAppUniqueName
      entraAppDisplayName: agent.entraAppDisplayName
      agentAppId: agentEntraApps[i].outputs.entraAppClientId
      agentScopeId: agentEntraApps[i].outputs.entraAppScopeId
      foundryServerAppId: entraAppServer.outputs.entraAppClientId
      foundryScopeId: entraAppServer.outputs.entraAppScopeId
    }
  }
]

module dataverseApplicationUser '../../modules/dataverse-application-user.bicep' = {
  name: 'dataverse-application-user'
  params: {
    name: '${foundryAppName}-dataverse-setup'
    location: location
    tags: tags
    dataverseUrl: dataverseUrl
    applicationClientId: foundryManagedIdentity.outputs.clientId
    securityRoleId: dataverseSecurityRoleId
    identityId: setupManagedIdentityId
  }
}

// ----------------------------------------------------------------------------------------------
// Container Apps
// ----------------------------------------------------------------------------------------------

// Container Apps terminates TLS at ingress, so the apps' HTTPS redirection has no port to redirect to.
var commonEnv = [
  { name: 'ASPNETCORE_ENVIRONMENT', value: 'Production' }
  { name: 'ASPNETCORE_URLS', value: 'http://+:8080' }
  { name: 'DANGEROUSLY_DISABLE_HTTPS_REDIRECTION', value: 'true' }
  { name: 'AzureAd__Instance', value: environment().authentication.loginEndpoint }
  { name: 'AzureAd__TenantId', value: tenant().tenantId }
  { name: 'AzureAd__ClientCredentials__0__SourceType', value: 'SignedAssertionFromManagedIdentity' }
  { name: 'LOG_LEVEL', value: logLevel }
  { name: 'COLLECT_TELEMETRY', value: string(!empty(monitoring.outputs.connectionString)) }
]

var telemetryEnv = !empty(monitoring.outputs.connectionString)
  ? [{ name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: monitoring.outputs.connectionString }]
  : []

module foundryContainerApp '../../modules/container-app.bicep' = {
  name: 'foundry-container-app'
  params: {
    location: location
    containerAppName: foundryAppName
    environmentId: containerAppsEnvironment.outputs.id
    image: '${imageRegistry}/logic-fabric-dataverse-foundry:${imageTagOverrides.?foundry ?? imageTag}'
    userAssignedManagedIdentityId: foundryManagedIdentity.outputs.resourceId
    customDomain: foundryCustomDomain
    certificateId: certificateIdsByDomain[?foundryCustomDomain] ?? ''
    sizing: foundrySizing
    allowedIpRanges: allowedIpRanges
    tags: tags
    env: concat(
      commonEnv,
      [
        { name: 'AzureAd__ClientId', value: entraAppServer.outputs.entraAppClientId }
        { name: 'AzureAd__ClientCredentials__0__ManagedIdentityClientId', value: foundryManagedIdentity.outputs.clientId }
        { name: 'MCP_SERVER_TRANSPORT_TYPE', value: 'Http' }
        { name: 'DATAVERSE__AUTHENTICATION_STRATEGY', value: 'OnBehalfOf' }
        { name: 'DATAVERSE__URL', value: dataverseUrl }
        { name: 'DATAVERSE__SCOPES', value: '${dataverseUrl}.default' }
      ],
      telemetryEnv
    )
  }
}

module agentContainerApps '../../modules/container-app.bicep' = [
  for (agent, i) in agents: {
    name: '${agent.key}-container-app'
    dependsOn: [
      redis
    ]
    params: {
      location: location
      containerAppName: agent.containerAppName
      environmentId: containerAppsEnvironment.outputs.id
      image: agent.image
      userAssignedManagedIdentityId: agentManagedIdentities[i].outputs.resourceId
      customDomain: agent.customDomain
      certificateId: certificateIdsByDomain[?agent.customDomain] ?? ''
      sizing: agentSizing
      allowedIpRanges: allowedIpRanges
      tags: tags
      secrets: union(
        { 'redis-connection-string': redisConnectionString },
        !empty(selectedLlmApiKey) ? { 'llm-api-key': selectedLlmApiKey } : {}
      )
      env: concat(
        commonEnv,
        [
          { name: 'AzureAd__ClientId', value: agentEntraApps[i].outputs.entraAppClientId }
          { name: 'AzureAd__ClientCredentials__0__ManagedIdentityClientId', value: agentManagedIdentities[i].outputs.clientId }
          { name: 'FOUNDRY_MCP_SERVER__AUTHENTICATION_STRATEGY', value: 'OnBehalfOf' }
          { name: 'FOUNDRY_MCP_SERVER__URL', value: '${foundryContainerApp.outputs.containerAppUrl}/mcp' }
          { name: 'FOUNDRY_MCP_SERVER__SCOPES', value: 'api://${entraAppServer.outputs.entraAppClientId}/${foundryScopeValue}' }
          { name: 'LLM_PROVIDER', value: llmProviderEnvValue }
          { name: 'LLM_MAX_CONCURRENCY', value: string(llmMaxConcurrency) }
          { name: 'REDIS_CONNECTION_STRING', secretRef: 'redis-connection-string' }
        ],
        llmEnvByProvider[llmProvider],
        !empty(selectedLlmApiKey) ? [{ name: llmApiKeyEnvNameByProvider[llmProvider], secretRef: 'llm-api-key' }] : [],
        telemetryEnv
      )
    }
  }
]

// ----------------------------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------------------------

output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = resourceGroup().name

output FOUNDRY_CONTAINER_APP_NAME string = foundryContainerApp.outputs.containerAppName
output FOUNDRY_URL string = foundryContainerApp.outputs.containerAppUrl
output FOUNDRY_CUSTOM_DOMAIN_URL string = foundryContainerApp.outputs.customDomainUrl
output FOUNDRY_MANAGED_IDENTITY_CLIENT_ID string = foundryManagedIdentity.outputs.clientId
output FOUNDRY_SERVER_APP_ID string = entraAppServer.outputs.entraAppClientId
output FOUNDRY_SCOPE string = 'api://${entraAppServer.outputs.entraAppClientId}/${foundryScopeValue}'
output FOUNDRY_CLIENT_APP_ID string = entraAppClient.outputs.entraAppClientId
output DATAVERSE_APPLICATION_USER_ID string = dataverseApplicationUser.outputs.systemUserId

output AGENT_APPS array = [
  for (agent, i) in agents: {
    key: agent.key
    containerAppName: agentContainerApps[i].outputs.containerAppName
    url: agentContainerApps[i].outputs.containerAppUrl
    customDomainUrl: agentContainerApps[i].outputs.customDomainUrl
    entraAppId: agentEntraApps[i].outputs.entraAppClientId
    managedIdentityClientId: agentManagedIdentities[i].outputs.clientId
  }
]

output CONTAINER_APPS_ENVIRONMENT_ID string = containerAppsEnvironment.outputs.id
output CUSTOM_DOMAIN_VERIFICATION_ID string = containerAppsEnvironment.outputs.customDomainVerificationId
output REDIS_CONTAINER_APP_NAME string = useInternalRedis ? redis!.outputs.containerAppName : ''
output APPLICATION_INSIGHTS_CONNECTION_STRING string = monitoring.outputs.connectionString
