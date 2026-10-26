// Parameters for deploying with the Azure CLI instead of azd:
//   az deployment group create -g <resource-group> -f main.bicep -p deploy.bicepparam
// Values are read from environment variables; see the README. azd ignores this file.
using 'main.bicep'

param dataverseUrl = readEnvironmentVariable('DATAVERSE_URL')
param setupManagedIdentityId = readEnvironmentVariable('SETUP_MANAGED_IDENTITY_ID')
param flowonProjects = readEnvironmentVariable('FLOWON_PROJECTS', '')

param tags = {
  workload: 'logic-fabric'
}
