// Parameters for deploying with the Azure CLI instead of azd:
//   az deployment group create -g <resource-group> -f main.bicep -p deploy.bicepparam
// Values are read from environment variables; see the README. azd ignores this file.
using 'main.bicep'

param dataverseUrl = readEnvironmentVariable('DATAVERSE_URL')
param setupManagedIdentityId = readEnvironmentVariable('SETUP_MANAGED_IDENTITY_ID')

// Keep this value: changing it disconnects running agents from Redis until they restart.
param redisPassword = readEnvironmentVariable('REDIS_PASSWORD')

param llmProvider = 'AzureFoundryAnthropic'
param azureFoundryAnthropicEndpoint = readEnvironmentVariable('AZURE_FOUNDRY_ANTHROPIC_ENDPOINT', '')
param azureFoundryAnthropicModel = readEnvironmentVariable('AZURE_FOUNDRY_ANTHROPIC_MODEL', '')
param azureFoundryAnthropicApiKey = readEnvironmentVariable('AZURE_FOUNDRY_ANTHROPIC_API_KEY', '')

param tags = {
  workload: 'logic-fabric'
}
