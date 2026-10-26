// Copyright (c) 2026 Flowon Corp. Licensed under the MIT License.
// Derived from Azure-Samples/azmcp-obo-template, Copyright (c) Microsoft Corporation (MIT).
//
// Managed certificates and environment storage are child resources that ARM only resolves when the
// environment is declared in the same template, so they live here rather than in container-app.bicep
// and redis.bicep. Callers pass their custom domains in and look up certificate IDs from the output.

import { networkingType } from 'types.bicep'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Name for the Container Apps environment')
param name string

@description('Tags applied to every resource')
param tags object = {}

@description('Custom domains to issue free, CNAME-validated managed certificates for. Empty entries are ignored.')
param customDomains array = []

@description('Log Analytics workspace in this resource group to send container console and system logs to. Leave empty to not collect logs.')
param logAnalyticsWorkspaceName string = ''

@description('Optional virtual network integration')
param network networkingType?

@description('Storage account in this resource group backing the Redis volume. Leave empty to skip registering environment storage.')
param redisStorageAccountName string = ''

@description('File share on the storage account above')
param redisFileShareName string = ''

var domains = filter(customDomains, d => !empty(d))

// Keys are read here rather than passed in, so they never travel through deployment parameters.
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = if (!empty(logAnalyticsWorkspaceName)) {
  name: logAnalyticsWorkspaceName
}

resource redisStorageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' existing = if (!empty(redisStorageAccountName)) {
  name: redisStorageAccountName
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2025-01-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: !empty(logAnalyticsWorkspaceName)
      ? {
          destination: 'log-analytics'
          logAnalyticsConfiguration: {
            customerId: logAnalyticsWorkspace!.properties.customerId
            sharedKey: logAnalyticsWorkspace!.listKeys().primarySharedKey
          }
        }
      : null
    vnetConfiguration: network != null
      ? {
          infrastructureSubnetId: network!.infrastructureSubnetId
          internal: network.?internal ?? false
        }
      : null
    zoneRedundant: network.?zoneRedundant ?? false
  }
}

resource managedCertificates 'Microsoft.App/managedEnvironments/managedCertificates@2025-01-01' = [
  for domain in domains: {
    parent: containerAppsEnvironment
    name: replace(domain, '.', '-')
    location: location
    tags: tags
    properties: {
      subjectName: domain
      domainControlValidation: 'CNAME'
    }
  }
]

resource redisStorage 'Microsoft.App/managedEnvironments/storages@2025-01-01' = if (!empty(redisStorageAccountName)) {
  parent: containerAppsEnvironment
  name: 'redis-storage'
  properties: {
    azureFile: {
      accountName: redisStorageAccountName
      accountKey: redisStorageAccount!.listKeys().keys[0].value
      shareName: redisFileShareName
      accessMode: 'ReadWrite'
    }
  }
}

output id string = containerAppsEnvironment.id
output name string = containerAppsEnvironment.name
output defaultDomain string = containerAppsEnvironment.properties.defaultDomain

@description('Value for the "asuid.<domain>" TXT record every custom domain in this environment needs')
output customDomainVerificationId string = containerAppsEnvironment.properties.customDomainConfiguration.customDomainVerificationId

@description('One { domain, certificateId } entry per custom domain')
output certificateIds array = [
  for (domain, i) in domains: {
    domain: domain
    certificateId: managedCertificates[i].id
  }
]

@description('Environment storage name for the Redis volume, or empty when no storage was registered')
output redisStorageName string = !empty(redisStorageAccountName) ? redisStorage.name : ''
