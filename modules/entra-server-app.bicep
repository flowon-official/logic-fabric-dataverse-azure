// Copyright (c) 2026 Flowon Corp. Licensed under the MIT License.
// Derived from Azure-Samples/azmcp-obo-template, Copyright (c) Microsoft Corporation (MIT).
//
// Entra app for an MCP server (Foundry or Conductor). It exposes one delegated scope, calls
// Dataverse on behalf of the signed-in user, and authenticates as its Container App's managed
// identity through a federated credential, so no client secret exists.

extension microsoftGraphV1

@description('Display name for the Entra application')
param entraAppDisplayName string

@description('Unique name for the Entra application')
param entraAppUniqueName string

@description('Value of the delegated scope the app exposes')
param entraAppScopeValue string

@description('Display name of the scope')
param entraAppScopeDisplayName string

@description('Description of the scope')
param entraAppScopeDescription string

@description('App ID of a client pre-authorized to request the scope without a consent prompt (e.g. the dev/CLI client)')
param knownClientAppId string = ''

@description('More pre-authorized client app IDs (e.g. each agent). Separate from knownClientAppId because Bicep only allows a for-expression over module outputs directly as a module parameter.')
param additionalKnownClientAppIds array = []

@description('Object (principal) ID of the Container App\'s user-assigned managed identity')
param acaManagedIdentityObjectId string

@description('Grant tenant-wide admin consent for the Dataverse user_impersonation permission. Needs Global Administrator or Privileged Role Administrator; set to false and grant consent in the portal otherwise.')
param grantAdminConsent bool = true

@description('Optional Service Management Reference GUID linking the app to a service in your tenant')
param serviceManagementReference string = ''

var dataverseAppId = '00000007-0000-0000-c000-000000000000'
var dataverseUserImpersonationScopeId = '78ce3f0f-a1ce-49c2-8cde-64b5c0896db4'
var scopeId = guid(entraAppUniqueName, entraAppScopeValue)
var knownClientAppIds = !empty(knownClientAppId)
  ? concat([knownClientAppId], additionalKnownClientAppIds)
  : additionalKnownClientAppIds
var preAuthorizedKnownClients = [
  for appId in knownClientAppIds: {
    appId: appId
    delegatedPermissionIds: [
      scopeId
    ]
  }
]

resource entraApp 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: entraAppUniqueName
  displayName: entraAppDisplayName
  serviceManagementReference: !empty(serviceManagementReference) ? serviceManagementReference : null
  api: {
    oauth2PermissionScopes: [
      {
        id: scopeId
        type: 'User'
        adminConsentDescription: entraAppScopeDescription
        adminConsentDisplayName: entraAppScopeDisplayName
        userConsentDescription: entraAppScopeDescription
        userConsentDisplayName: entraAppScopeDisplayName
        value: entraAppScopeValue
        isEnabled: true
      }
    ]
    requestedAccessTokenVersion: 2
  }
  requiredResourceAccess: [
    {
      resourceAppId: dataverseAppId
      resourceAccess: [
        {
          id: dataverseUserImpersonationScopeId
          type: 'Scope'
        }
      ]
    }
  ]
  isFallbackPublicClient: false
}

resource servicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: entraApp.appId
}

// Dataverse's first-party service principal, present in every tenant with Power Platform.
resource dataverseServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' existing = {
  appId: dataverseAppId
}

// Without this consent, the headless OBO exchange to Dataverse fails with AADSTS65001.
resource dataverseConsentGrant 'Microsoft.Graph/oauth2PermissionGrants@v1.0' = if (grantAdminConsent) {
  clientId: servicePrincipal.id
  resourceId: dataverseServicePrincipal.id
  consentType: 'AllPrincipals'
  scope: 'user_impersonation'
}

// The Application ID URI and self pre-authorization both need the app's own appId, which only exists
// once Graph has created the app, so they are applied as a second write to the same app.
resource entraAppSelfConfiguration 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: entraApp.uniqueName
  displayName: entraAppDisplayName
  identifierUris: [
    'api://${entraApp.appId}'
  ]
  api: {
    preAuthorizedApplications: concat(preAuthorizedKnownClients, [
      {
        appId: entraApp.appId
        delegatedPermissionIds: [
          scopeId
        ]
      }
    ])
  }
}

resource federatedIdentityCredential 'Microsoft.Graph/applications/federatedIdentityCredentials@v1.0' = {
  name: '${entraApp.uniqueName}/ServerClientCredential'
  audiences: [
    'api://AzureADTokenExchange'
  ]
  description: 'Client credential for the ${entraAppDisplayName} Container App'
  issuer: '${environment().authentication.loginEndpoint}${tenant().tenantId}/v2.0'
  subject: acaManagedIdentityObjectId
}

output entraAppClientId string = entraApp.appId
output entraAppScopeId string = scopeId
output entraAppScopeValue string = entraAppScopeValue
