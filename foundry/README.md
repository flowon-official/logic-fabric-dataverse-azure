# Foundry and agents

Deploys the **Foundry** MCP server and the Logic Fabric agents (**Assist**, **Assurance**,
**Context**, **Guard**, **Insight** and **Sentinel**) into one Azure Container Apps environment.
It also creates the Entra app registrations that let each agent call Foundry, and Foundry call
Dataverse, on behalf of the signed-in user.

## What gets deployed

| Resource | Count | Notes |
|---|---|---|
| Container Apps environment | 1 | Sends container logs to Log Analytics when telemetry is enabled |
| Container App: Foundry | 1 | `flowon/logic-fabric-dataverse-foundry` |
| Container App: agents | 1 per agent | `flowon/logic-fabric-dataverse-<agent>`; choose agents with `enabledAgents` |
| Container App: Redis | 1 | Internal-only cache for agent workflow and session state. Skipped when you bring your own Redis. |
| Storage account with file share | 1 | Holds Redis snapshots so they survive restarts. Skipped with your own Redis. |
| User-assigned managed identity | 1 per app | Each app's federated credential trusts only its own identity |
| Entra app: Foundry server | 1 | Exposes `Mcp.Tools.ReadWrite`, pre-authorizes the dev client and every agent, and holds the Dataverse `user_impersonation` permission |
| Entra app: Foundry dev client | 1 | Public client for MCP tooling such as VS Code |
| Entra app: one per agent | 1 per agent | Sign-in for the agent's web app (`Agent.AsUser` scope) and on-behalf-of client to Foundry |
| Dataverse Application User | 1 | For Foundry's managed identity, with the `dataverseSecurityRoleId` role |
| Application Insights and Log Analytics | 1 each | Optional; see `appInsightsConnectionString` |
| Managed certificate | 1 per custom domain | Optional |

Names derive from `namePrefix`: `<prefix>-foundry`, `<prefix>-assist`, `<prefix>-redis`,
`<prefix>-foundry-env` and so on.

## Prerequisites

See [Before you start](../README.md#before-you-start). You also need an LLM endpoint and key for
one of the [supported providers](#llm-provider).

## Deploy with azd

```bash
cd foundry
azd env new <environment-name>

# Required
azd env set dataverseUrl "https://your-org.crm.dynamics.com/"
azd env set setupManagedIdentityId "<resource ID printed by New-DataverseSetupIdentity.ps1>"

# LLM provider (the default, AzureFoundryAnthropic, shown)
azd env set azureFoundryAnthropicEndpoint "https://<resource>.services.ai.azure.com/anthropic"
azd env set azureFoundryAnthropicModel "<deployment-name>"
azd env set azureFoundryAnthropicApiKey "<key>"

azd provision
```

azd asks for a subscription, location and resource group the first time. It also generates the
Redis password and keeps it in the azd environment, so later provisions reuse it.

The first provision into a new tenant can fail with `Request_ResourceNotFound` or "property
'appId' doesn't exist". This is a Microsoft Graph replication delay
([Azure/bicep#16811](https://github.com/Azure/bicep/issues/16811)). Run `azd provision` again; it
picks up where it stopped.

## Deploy with the Azure CLI

```bash
cd foundry/infra
export DATAVERSE_URL="https://your-org.crm.dynamics.com/"
export SETUP_MANAGED_IDENTITY_ID="<resource ID>"
export REDIS_PASSWORD="<32 random letters and digits; keep it for later deployments>"
export AZURE_FOUNDRY_ANTHROPIC_ENDPOINT="https://<resource>.services.ai.azure.com/anthropic"
export AZURE_FOUNDRY_ANTHROPIC_MODEL="<deployment-name>"
export AZURE_FOUNDRY_ANTHROPIC_API_KEY="<key>"

az group create --name <resource-group> --location <location>
az deployment group create --resource-group <resource-group> \
  --template-file main.bicep --parameters deploy.bicepparam
```

Edit [`infra/deploy.bicepparam`](infra/deploy.bicepparam) to set other parameters.

## Parameters

With azd, string parameters are set with `azd env set <name> <value>`. Number, boolean, array and
object parameters are set by editing [`infra/main.parameters.json`](infra/main.parameters.json).

### General

| Parameter | Default | Description |
|---|---|---|
| `dataverseUrl` | *required* | Dataverse environment URL |
| `setupManagedIdentityId` | *required* | Resource ID of the setup identity (see [Before you start](../README.md#before-you-start)) |
| `namePrefix` | `logic-fabric` | Resource name prefix, 2–22 characters: lowercase letters, digits and hyphens, starting with a letter |
| `displayNamePrefix` | `Flowon Logic Fabric` | Prefix for Entra app display names |
| `enabledAgents` | all six | Agents to deploy, e.g. `["assist", "guard"]` |
| `tags` | `{ "workload": "logic-fabric" }` | Tags applied to every Azure resource |
| `imageTag` | `1.0.0` | Image tag for Foundry and every agent |
| `imageTagOverrides` | `{}` | Per-image tags, e.g. `{ "assist": "1.0.1" }` |
| `imageRegistry` | `docker.io/flowon` | Registry and namespace to pull from; must allow anonymous pulls |
| `logLevel` | `Warning` | `Trace`, `Debug`, `Information`, `Warning`, `Error` or `Critical` |
| `foundrySizing`, `agentSizing` | `{}` | `{ "cpuCores": "1", "memorySize": "2Gi", "minReplicas": 2, "maxReplicas": 5 }`. Defaults: 0.5 vCPU, 1Gi, 1–3 replicas |
| `enableTelemetry` | `true` | Azure Verified Modules usage telemetry to Microsoft |

### Identity and Dataverse

| Parameter | Default | Description |
|---|---|---|
| `dataverseSecurityRoleId` | Logic Fabric Author | Role assigned to Foundry's Application User. Must exist in the environment. |
| `grantAdminConsent` | `true` | Grants tenant-wide consent for Foundry's Dataverse permission. Set to `false` if you lack Global Administrator or Privileged Role Administrator, then grant consent under **App registrations › Foundry MCP Server › API permissions**. |
| `entraAppClientId` | *(create)* | Reuse an existing Foundry dev client app |
| `agentEntraAppIds` | `{}` | Reuse existing agent apps, e.g. `{ "guard": "<app ID>" }`. Their API permissions are left as they are. |
| `serviceManagementReference` | *(none)* | Service Management Reference GUID for the Entra apps |

### LLM provider

`llmProvider` picks the provider; only that provider's parameters are used. API keys are stored as
Container Apps secrets.

| `llmProvider` | Required | Optional (default) |
|---|---|---|
| `AzureFoundryAnthropic` *(default)*: Claude on Azure AI Foundry | `azureFoundryAnthropicEndpoint`, `azureFoundryAnthropicApiKey`, `azureFoundryAnthropicModel` | `azureFoundryAnthropicTimeoutMinutes` (10), `azureFoundryAnthropicMaxOutputTokens` (16384), `azureFoundryAnthropicVersion` (2023-06-01) |
| `AzureFoundry`: Azure AI Inference models | `azureFoundryEndpoint`, `azureFoundryApiKey`, `azureFoundryModel` | |
| `AzureOpenAI`: Azure OpenAI | `azureFoundryOpenAIEndpoint`, `azureFoundryOpenAIApiKey`, `azureFoundryOpenAIModel` | |
| `OpenAI` | `openAIApiKey`, `openAIModel` | |
| `Anthropic` | `anthropicApiKey`, `anthropicModel` | `anthropicTimeoutMinutes` (10), `anthropicMaxOutputTokens` (16384), `anthropicVersion` (2023-06-01) |

`llmMaxConcurrency` (default 4) caps concurrent LLM requests per agent.

### Networking and Redis

| Parameter | Default | Description |
|---|---|---|
| `allowedIpRanges` | `[]` (all) | IPv4 addresses or CIDR ranges allowed to reach Foundry and the agents. Agent web apps run in users' browsers, so include their ranges. |
| `network` | *(none)* | Virtual network integration: `{ "infrastructureSubnetId": "<subnet ID>", "internal": false, "zoneRedundant": false }`. The subnet must be /23 or larger and not delegated. With `internal: true`, apps get only private IPs; you provide DNS and inbound access. |
| `foundryCustomDomain`, `agentCustomDomains` | *(none)* | See [Custom domains](#custom-domains) |
| `externalRedisConnectionString` | *(internal Redis)* | StackExchange.Redis connection string for your own Redis, such as Azure Managed Redis. Skips the internal Redis and its storage. |
| `redisPassword` | *generated by azd* | Internal Redis password. Keep it stable: changing it disconnects running agents until they restart. |
| `appInsightsConnectionString` | *(create)* | Reuse an existing Application Insights resource, or `DISABLED` to turn telemetry off. Container logs only go to Log Analytics when this template creates the workspace. |

The internal Redis is a single container that snapshots to Azure Files. It survives restarts and
redeploys, but writes since the last snapshot (up to 60 seconds) are lost if it crashes, and it
has no failover. For production, use Azure Managed Redis through `externalRedisConnectionString`.

## Custom domains

Azure issues a free managed certificate once DNS points at the app:

1. Provision once without the domain. Note the app's default hostname (`FOUNDRY_URL` or
   `AGENT_APPS`) and `CUSTOM_DOMAIN_VERIFICATION_ID` from `azd env get-values`.
2. Create a CNAME record for your domain pointing at the default hostname.
3. Create a TXT record at `asuid.<your domain>` with the verification ID.
4. Set `foundryCustomDomain` (`azd env set`) or `agentCustomDomains` (in `main.parameters.json`,
   e.g. `{ "guard": "guard.contoso.com" }`) and provision again.

If the certificate fails because DNS hasn't propagated yet, provision again later. Agent custom
domains are also added as sign-in redirect URIs on the agent's Entra app.

## Outputs

`azd env get-values` shows:

| Output | Description |
|---|---|
| `FOUNDRY_URL`, `FOUNDRY_CUSTOM_DOMAIN_URL` | Foundry's URLs; the MCP endpoint is `<url>/mcp` |
| `FOUNDRY_SCOPE` | Scope MCP clients request for Foundry |
| `FOUNDRY_SERVER_APP_ID`, `FOUNDRY_CLIENT_APP_ID` | Foundry Entra app IDs |
| `AGENT_APPS` | One `{ key, containerAppName, url, customDomainUrl, entraAppId, managedIdentityClientId }` per agent |
| `CUSTOM_DOMAIN_VERIFICATION_ID` | TXT record value for custom domains |
| `DATAVERSE_APPLICATION_USER_ID` | Foundry's Dataverse `systemuserid` |
| `APPLICATION_INSIGHTS_CONNECTION_STRING` | Empty when telemetry is disabled |

## Upgrading

Set a newer `imageTag` (or individual `imageTagOverrides`) and run `azd provision`. Check the
[changelog](../CHANGELOG.md) when moving to a new template release.

## Removing a deployment

```bash
azd down --purge
```

This deletes the resource group. It does not delete the Entra app registrations, which belong to
the tenant rather than the resource group
([Azure/azure-dev#4724](https://github.com/Azure/azure-dev/issues/4724)). Delete them with
`az ad app delete --id <app ID>`, using the IDs from the outputs. To keep them for a later
deployment, pass them back in with `entraAppClientId` and `agentEntraAppIds` instead.

## Troubleshooting

- **`AADSTS65001` ("has not consented") when Foundry calls Dataverse.** Admin consent was not
  granted. Grant it in the Entra admin center (see `grantAdminConsent`), or provision again as a
  Global Administrator or Privileged Role Administrator.
- **The `<prefix>-foundry-dataverse-setup` deployment script fails.** Usually the setup identity
  lacks System Administrator in this Dataverse environment (HTTP 401 or 403), or the
  `dataverseSecurityRoleId` role does not exist ("Security role ... was not found"). The script's
  log is on the deployment script resource in the portal for a day after a failure. Fix the
  cause and provision again. If ARM then reports the resource "already exists or is in a
  conflicting state", delete the deployment script resource first.
- **An agent's sign-in fails after you add a custom domain.** Provision again so the domain is
  added as a redirect URI.
- **A deployment fails with a container app name error.** Names are limited to 32 characters;
  keep `namePrefix` at 22 characters or fewer.
