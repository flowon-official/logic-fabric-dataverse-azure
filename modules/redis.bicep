// Copyright (c) 2026 Flowon Corp. Licensed under the MIT License.
//
// Internal Redis for the agents' distributed cache (workflow and session state), run as a single
// internal-only Container App. It is not highly available: one replica, no clustering. With
// environmentStorageName set, it writes RDB snapshots to an Azure Files volume so data survives
// restarts and redeploys; writes since the last snapshot are lost on a crash. RDB is used rather
// than AOF because AOF's frequent fsyncs perform poorly over SMB. For production durability, pass
// an Azure Managed Redis connection string to main.bicep's externalRedisConnectionString instead.

@description('Location for all resources')
param location string = resourceGroup().location

@description('Container App name for the Redis instance')
param containerAppName string

@description('Resource ID of the Container Apps environment to deploy into')
param environmentId string

@description('Redis image to run')
param image string = 'docker.io/library/redis:7.4-alpine'

@secure()
@description('Redis password. Must stay the same across deployments, or running agents lose their connection.')
param redisPassword string

@description('Environment storage name to mount at /data for persistence. Leave empty for ephemeral storage.')
param environmentStorageName string = ''

@description('Tags applied to the Container App')
param tags object = {}

var persistent = !empty(environmentStorageName)
var volumeName = 'redis-data'

resource containerApp 'Microsoft.App/containerApps@2025-01-01' = {
  name: containerAppName
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      activeRevisionsMode: 'Single'
      secrets: [
        {
          name: 'redis-password'
          value: redisPassword
        }
      ]
      ingress: {
        external: false
        targetPort: 6379
        // Other apps connect on exposedPort, which does not reliably default to targetPort for TCP.
        exposedPort: 6379
        transport: 'tcp'
        allowInsecure: false
      }
    }
    template: {
      containers: [
        {
          image: image
          name: containerAppName
          command: [
            'sh'
            '-c'
          ]
          args: [
            // The password comes from a secret-backed env var so it never appears in deployment history.
            persistent
              ? 'redis-server --requirepass "$REDIS_PASSWORD" --dir /data --save 60 1 --save 300 100 --latency-monitor-threshold 100'
              : 'redis-server --requirepass "$REDIS_PASSWORD" --latency-monitor-threshold 100'
          ]
          env: [
            {
              name: 'REDIS_PASSWORD'
              secretRef: 'redis-password'
            }
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          volumeMounts: persistent
            ? [
                {
                  volumeName: volumeName
                  mountPath: '/data'
                }
              ]
            : []
        }
      ]
      volumes: persistent
        ? [
            {
              name: volumeName
              storageType: 'AzureFile'
              storageName: environmentStorageName
            }
          ]
        : []
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

output containerAppName string = containerApp.name
