// Copyright (c) 2026 Flowon Corp. Licensed under the MIT License.
// Derived from Azure-Samples/azmcp-obo-template, Copyright (c) Microsoft Corporation (MIT).
//
// Entra app for one agent. The same app is both the sign-in target for the agent's single-page app
// (which requests the app's own Agent.AsUser scope) and the on-behalf-of client that exchanges the
// user's token for one scoped to Foundry, authenticating through a federated credential trusting
// the agent's managed identity.

extension microsoftGraphV1

@description('Display name for the agent Entra application')
param entraAppDisplayName string

@description('Unique name for the agent Entra application')
param entraAppUniqueName string

@description('App ID of an existing agent application to reuse. If empty, a new one is created.')
param entraAppId string = ''

@description('Scope the agent\'s single-page app requests at sign-in. The agent images expect Agent.AsUser.')
param entraAppScopeValue string = 'Agent.AsUser'

@description('Single-page app redirect URIs: every hostname the agent is reachable on')
param spaRedirectUris array

@description('Object (principal) ID of the agent Container App\'s user-assigned managed identity')
param acaManagedIdentityObjectId string

@description('Optional Service Management Reference GUID linking the app to a service in your tenant')
param serviceManagementReference string = ''

var shouldCreate = empty(entraAppId)
var scopeId = guid(entraAppUniqueName, entraAppScopeValue)

resource entraApp 'Microsoft.Graph/applications@v1.0' = if (shouldCreate) {
  uniqueName: entraAppUniqueName
  displayName: entraAppDisplayName
  serviceManagementReference: !empty(serviceManagementReference) ? serviceManagementReference : null
  spa: {
    redirectUris: spaRedirectUris
  }
  api: {
    oauth2PermissionScopes: [
      {
        id: scopeId
        type: 'User'
        adminConsentDescription: 'Allow the ${entraAppDisplayName} web app to call its own API on behalf of the signed-in user'
        adminConsentDisplayName: '${entraAppDisplayName} sign-in'
        userConsentDescription: 'Allow the ${entraAppDisplayName} web app to call its own API on behalf of the signed-in user'
        userConsentDisplayName: '${entraAppDisplayName} sign-in'
        value: entraAppScopeValue
        isEnabled: true
      }
    ]
    requestedAccessTokenVersion: 2
  }
  isFallbackPublicClient: false
}

resource servicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = if (shouldCreate) {
  appId: entraApp!.appId
}

// The SPA and the API are the same app, so it pre-authorizes itself to skip a consent prompt on
// first sign-in. This and the Application ID URI need the app's own appId, so they are a second
// write to the same app; Graph merges api properties, keeping the scope defined above.
resource entraAppSelfAuthorization 'Microsoft.Graph/applications@v1.0' = if (shouldCreate) {
  uniqueName: entraAppUniqueName
  displayName: entraAppDisplayName
  identifierUris: [
    'api://${entraApp!.appId}'
  ]
  api: {
    preAuthorizedApplications: [
      {
        appId: entraApp!.appId
        delegatedPermissionIds: [
          scopeId
        ]
      }
    ]
  }
}

resource federatedIdentityCredential 'Microsoft.Graph/applications/federatedIdentityCredentials@v1.0' = if (shouldCreate) {
  name: '${entraApp!.uniqueName}/AgentClientCredential'
  audiences: [
    'api://AzureADTokenExchange'
  ]
  description: 'Client credential for the ${entraAppDisplayName} Container App'
  issuer: '${environment().authentication.loginEndpoint}${tenant().tenantId}/v2.0'
  subject: acaManagedIdentityObjectId
}

output entraAppClientId string = shouldCreate ? entraApp!.appId : entraAppId
output entraAppScopeId string = scopeId
