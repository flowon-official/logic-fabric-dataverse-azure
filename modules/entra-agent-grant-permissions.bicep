// Copyright (c) 2026 Flowon Corp. Licensed under the MIT License.
// Derived from Azure-Samples/azmcp-obo-template, Copyright (c) Microsoft Corporation (MIT).
//
// Sets an agent app's API permissions: its own Agent.AsUser scope and Foundry's scope. This runs
// after Foundry's server app exists, since Foundry pre-authorizes each agent by ID and the agent
// needs Foundry's IDs here. Both entries go in one write because Graph replaces
// requiredResourceAccess wholesale.

extension microsoftGraphV1

@description('Unique name of the agent Entra application created by entra-agent-app.bicep')
param entraAppUniqueName string

@description('Display name of the agent Entra application')
param entraAppDisplayName string

@description('The agent\'s app ID')
param agentAppId string

@description('The agent\'s Agent.AsUser scope ID')
param agentScopeId string

@description('Foundry server app ID')
param foundryServerAppId string

@description('Foundry server scope ID')
param foundryScopeId string

resource entraApp 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: entraAppUniqueName
  displayName: entraAppDisplayName
  requiredResourceAccess: [
    {
      resourceAppId: agentAppId
      resourceAccess: [
        {
          id: agentScopeId
          type: 'Scope'
        }
      ]
    }
    {
      resourceAppId: foundryServerAppId
      resourceAccess: [
        {
          id: foundryScopeId
          type: 'Scope'
        }
      ]
    }
  ]
}
