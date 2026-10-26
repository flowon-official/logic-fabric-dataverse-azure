// Copyright (c) 2026 Flowon Corp. Licensed under the MIT License.
// Derived from Azure-Samples/azmcp-obo-template, Copyright (c) Microsoft Corporation (MIT).
//
// Public client app for interactive MCP tooling (e.g. VS Code) signing in to the server app.

extension microsoftGraphV1

@description('Display name for the client Entra application')
param entraAppDisplayName string

@description('Unique name for the client Entra application')
param entraAppUniqueName string

@description('App ID of an existing client application to reuse. If empty, a new one is created.')
param entraAppId string = ''

@description('Optional Service Management Reference GUID linking the app to a service in your tenant')
param serviceManagementReference string = ''

var shouldCreate = empty(entraAppId)

resource entraApp 'Microsoft.Graph/applications@v1.0' = if (shouldCreate) {
  uniqueName: entraAppUniqueName
  displayName: entraAppDisplayName
  serviceManagementReference: !empty(serviceManagementReference) ? serviceManagementReference : null
  api: null
  requiredResourceAccess: []
  publicClient: {
    redirectUris: [
      'http://localhost'
    ]
  }
  isFallbackPublicClient: true
}

resource servicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = if (shouldCreate) {
  appId: entraApp!.appId
}

output entraAppClientId string = shouldCreate ? entraApp!.appId : entraAppId
