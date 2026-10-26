// Copyright (c) 2026 Flowon Corp. Licensed under the MIT License.

@export()
@description('Container size and scale settings. Omitted properties keep the module defaults.')
type containerSizingType = {
  @description('vCPU cores, e.g. \'0.5\'. Must pair with a supported memorySize (2 GiB per vCPU on the Consumption plan).')
  cpuCores: string?

  @description('Memory, e.g. \'1Gi\'')
  memorySize: string?

  @minValue(0)
  minReplicas: int?

  @minValue(1)
  maxReplicas: int?
}

@export()
@description('Minimum log level the Logic Fabric hosts read from LOG_LEVEL')
type logLevelType = 'Trace' | 'Debug' | 'Information' | 'Warning' | 'Error' | 'Critical'

@export()
@description('Optional virtual network integration for the Container Apps environment')
type networkingType = {
  @description('Resource ID of an existing subnet (/23 or larger, not delegated) for the environment\'s infrastructure')
  infrastructureSubnetId: string

  @description('When true, apps get only private IPs inside the virtual network; you provide DNS and inbound access. Defaults to false.')
  internal: bool?

  @description('Spread the environment across availability zones. The region must support zones. Defaults to false.')
  zoneRedundant: bool?
}
