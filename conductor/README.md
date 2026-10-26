# Conductor

Deploys the **Conductor** MCP server to Azure Container Apps. Conductor turns Logic Blocks, Logic
Flows and business processes that have **Expose as MCP Tool** turned on into MCP tools.

Tool calls run on behalf of the signed-in user. At startup, Conductor discovers the exposed
artifacts using its own managed identity. No client secret is involved in either case.

## What gets deployed

| Resource | Count | Notes |
|---|---|---|
| Container Apps environment | 1 | Sends container logs to Log Analytics when telemetry is enabled |
| Container App: Conductor | 1 | `flowon/logic-fabric-dataverse-conductor` |
| User-assigned managed identity | 1 | Used by the federated credential and startup tool discovery |
| Entra app: Conductor server | 1 | Exposes `Mcp.Tools.ReadWrite` and holds the Dataverse `user_impersonation` permission |
| Entra app: Conductor dev client | 1 | Public client for MCP tooling such as VS Code |
| Dataverse Application User | 1 | For Conductor's managed identity, with the `dataverseSecurityRoleId` role |
| Application Insights and Log Analytics | 1 each | Optional; see `appInsightsConnectionString` |
| Managed certificate | 0–1 | Only with a custom domain |

Names derive from `namePrefix`: `<prefix>-conductor`, `<prefix>-conductor-env` and so on.

## Prerequisites

See [Before you start](../README.md#before-you-start). The Dataverse environment also needs at
least one artifact with **Expose as MCP Tool** turned on in the projects you expose.

## Deploy with azd

```bash
cd conductor
azd env new <environment-name>

azd env set dataverseUrl "https://your-org.crm.dynamics.com/"
azd env set setupManagedIdentityId "<resource ID printed by New-DataverseSetupIdentity.ps1>"
azd env set flowonProjects "Sales;Finance"

azd provision
```

azd asks for a subscription, location and resource group the first time.

The first provision into a new tenant can fail with `Request_ResourceNotFound` or "property
'appId' doesn't exist". This is a Microsoft Graph replication delay
([Azure/bicep#16811](https://github.com/Azure/bicep/issues/16811)). Run `azd provision` again.

## Deploy with the Azure CLI

```bash
cd conductor/infra
export DATAVERSE_URL="https://your-org.crm.dynamics.com/"
export SETUP_MANAGED_IDENTITY_ID="<resource ID>"
export FLOWON_PROJECTS="Sales;Finance"

az group create --name <resource-group> --location <location>
az deployment group create --resource-group <resource-group> \
  --template-file main.bicep --parameters deploy.bicepparam
```

Edit [`infra/deploy.bicepparam`](infra/deploy.bicepparam) to set other parameters.

## Parameters

With azd, string parameters are set with `azd env set <name> <value>`. Number, boolean, array and
object parameters are set by editing [`infra/main.parameters.json`](infra/main.parameters.json).

| Parameter | Default | Description |
|---|---|---|
| `dataverseUrl` | *required* | Dataverse environment URL |
| `setupManagedIdentityId` | *required* | Resource ID of the setup identity (see [Before you start](../README.md#before-you-start)) |
| `flowonProjects` | *(none)* | Comma- or semicolon-separated Flowon project names to expose. With none, Conductor exposes no tools. |
| `namePrefix` | `logic-fabric` | Resource name prefix, 2–22 characters: lowercase letters, digits and hyphens, starting with a letter |
| `displayNamePrefix` | `Flowon Logic Fabric` | Prefix for Entra app display names |
| `tags` | `{ "workload": "logic-fabric" }` | Tags applied to every Azure resource |
| `imageTag` | `1.0.0` | Conductor image tag |
| `imageRegistry` | `docker.io/flowon` | Registry and namespace to pull from; must allow anonymous pulls |
| `logLevel` | `Warning` | `Trace`, `Debug`, `Information`, `Warning`, `Error` or `Critical` |
| `sizing` | `{}` | `{ "cpuCores": "0.5", "memorySize": "1Gi", "minReplicas": 2, "maxReplicas": 5 }`. Defaults: 0.25 vCPU, 0.5Gi, 1–3 replicas |
| `dataverseSecurityRoleId` | Logic Fabric Author | Role assigned to Conductor's Application User. Must exist in the environment. |
| `grantAdminConsent` | `true` | Grants tenant-wide consent for the Dataverse permission. Set to `false` if you lack Global Administrator or Privileged Role Administrator, then grant consent under **App registrations › Conductor MCP Server › API permissions**. |
| `entraAppClientId` | *(create)* | Reuse an existing dev client app |
| `serviceManagementReference` | *(none)* | Service Management Reference GUID for the Entra apps |
| `appInsightsConnectionString` | *(create)* | Reuse an existing Application Insights resource, or `DISABLED` to turn telemetry off |
| `allowedIpRanges` | `[]` (all) | IPv4 addresses or CIDR ranges allowed to reach Conductor |
| `network` | *(none)* | Virtual network integration: `{ "infrastructureSubnetId": "<subnet ID>", "internal": false, "zoneRedundant": false }`. The subnet must be /23 or larger and not delegated. |
| `customDomain` | *(none)* | See [Custom domain](#custom-domain) |
| `enableTelemetry` | `true` | Azure Verified Modules usage telemetry to Microsoft |

## Custom domain

1. Provision once without the domain. Note `CONDUCTOR_URL` and `CUSTOM_DOMAIN_VERIFICATION_ID`
   from `azd env get-values`.
2. Create a CNAME record for your domain pointing at the `CONDUCTOR_URL` hostname.
3. Create a TXT record at `asuid.<your domain>` with the verification ID.
4. `azd env set customDomain conductor.contoso.com` and provision again.

If the certificate fails because DNS hasn't propagated yet, provision again later.

## Outputs

| Output | Description |
|---|---|
| `CONDUCTOR_URL`, `CONDUCTOR_CUSTOM_DOMAIN_URL` | Conductor's URLs |
| `CONDUCTOR_SCOPE` | Scope MCP clients request for Conductor |
| `CONDUCTOR_SERVER_APP_ID`, `CONDUCTOR_CLIENT_APP_ID` | Entra app IDs |
| `CUSTOM_DOMAIN_VERIFICATION_ID` | TXT record value for a custom domain |
| `DATAVERSE_APPLICATION_USER_ID` | Conductor's Dataverse `systemuserid` |
| `APPLICATION_INSIGHTS_CONNECTION_STRING` | Empty when telemetry is disabled |

## Upgrading

Set a newer `imageTag` and run `azd provision`.

## Removing a deployment

```bash
azd down --purge
```

The two Entra app registrations remain
([Azure/azure-dev#4724](https://github.com/Azure/azure-dev/issues/4724)). Delete them with
`az ad app delete --id <app ID>`, or keep the dev client and pass it back in with
`entraAppClientId`.

## Troubleshooting

- **No tools appear.** Check `flowonProjects`. Conductor builds its tools at startup, so restart
  the app after changing which artifacts are exposed.
- **Conductor fails at startup with a Dataverse authentication error.** Its Application User
  isn't set up yet, or `dataverseSecurityRoleId` grants too little. Check the
  `DATAVERSE_APPLICATION_USER_ID` output and the deployment script below.
- **`AADSTS65001` ("has not consented") on tool calls.** Admin consent was not granted; see
  `grantAdminConsent`.
- **The `<prefix>-conductor-dataverse-setup` deployment script fails.** Usually the setup identity
  lacks System Administrator in this Dataverse environment (HTTP 401 or 403), or the
  `dataverseSecurityRoleId` role does not exist. The script's log is on the deployment script
  resource in the portal for a day after a failure. Fix the cause and provision again. If ARM then
  reports the resource "already exists or is in a conflicting state", delete the deployment script
  resource first.
