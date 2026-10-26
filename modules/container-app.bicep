// Copyright (c) 2026 Flowon Corp. Licensed under the MIT License.
// Derived from Azure-Samples/azmcp-obo-template, Copyright (c) Microsoft Corporation (MIT).
//
// A single externally reachable Container App, used for Foundry, Conductor and each agent.

import { containerSizingType } from 'types.bicep'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Container App name (2-32 characters)')
@minLength(2)
@maxLength(32)
param containerAppName string

@description('Resource ID of the Container Apps environment to deploy into')
param environmentId string

@description('Container image, e.g. docker.io/flowon/logic-fabric-dataverse-foundry:1.0.0. Must be anonymously pullable.')
param image string

@description('Environment variables. Entries use either "value" or "secretRef" (a key of the secrets parameter).')
param env array = []

@secure()
@description('Container Apps secrets as { name: value }, referenced from env through secretRef')
param secrets object = {}

@description('Port the container listens on')
param targetPort int = 8080

// Below 0.5 vCPU, cgroup CPU throttling was observed to stall Redis command dispatch for seconds under load.
@description('Container size and scale. Defaults: 0.5 vCPU, 1Gi, 1-3 replicas.')
param sizing containerSizingType = {}

@description('IPv4 addresses or CIDR ranges allowed to reach the app. Empty allows all.')
param allowedIpRanges string[] = []

@description('Resource ID of the user-assigned managed identity the app runs as')
param userAssignedManagedIdentityId string = ''

@description('Tags applied to the Container App')
param tags object = {}

@description('Optional custom domain. Needs a CNAME to the app\'s default hostname and an "asuid.<domain>" TXT record first.')
param customDomain string = ''

@description('Managed certificate resource ID for customDomain, from container-apps-environment.bicep. Required when customDomain is set.')
param certificateId string = ''

resource containerApp 'Microsoft.App/containerApps@2025-01-01' = {
  name: containerAppName
  location: location
  tags: tags
  identity: !empty(userAssignedManagedIdentityId)
    ? {
        type: 'UserAssigned'
        userAssignedIdentities: {
          '${userAssignedManagedIdentityId}': {}
        }
      }
    : null
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      activeRevisionsMode: 'Single'
      // The values come from the @secure() secrets object; the linter cannot see through items().
      #disable-next-line use-secure-value-for-secure-inputs
      secrets: [for secret in items(secrets): { name: secret.key, value: secret.value }]
      ingress: {
        external: true
        targetPort: targetPort
        allowInsecure: false
        transport: 'http'
        ipSecurityRestrictions: [
          for (range, i) in allowedIpRanges: {
            name: 'allow-${i}'
            action: 'Allow'
            ipAddressRange: range
          }
        ]
        customDomains: !empty(customDomain)
          ? [
              {
                name: customDomain
                bindingType: 'SniEnabled'
                certificateId: certificateId
              }
            ]
          : []
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
    }
    template: {
      containers: [
        {
          image: image
          name: containerAppName
          resources: {
            cpu: json(sizing.?cpuCores ?? '0.5')
            memory: sizing.?memorySize ?? '1Gi'
          }
          env: env
        }
      ]
      scale: {
        minReplicas: sizing.?minReplicas ?? 1
        maxReplicas: sizing.?maxReplicas ?? 3
        rules: [
          {
            name: 'http-scaler'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }
          }
        ]
      }
    }
  }
}

output containerAppName string = containerApp.name
output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output customDomainUrl string = !empty(customDomain) ? 'https://${customDomain}' : ''
