# Flowon Logic Fabric on Azure

[![Validate](https://github.com/flowon-official/logic-fabric-dataverse-azure/actions/workflows/validate.yml/badge.svg)](https://github.com/flowon-official/logic-fabric-dataverse-azure/actions/workflows/validate.yml)

Bicep templates for deploying the Flowon Logic Fabric AI services for Microsoft Dataverse to
Azure Container Apps. The templates provision the Azure resources, the Microsoft Entra app
registrations and the Dataverse Application Users. Deploy them with the
[Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/) (`azd`)
or the Azure CLI.

| Template | Deploys |
|---|---|
| [`foundry`](foundry) | The Foundry MCP server plus the Assist, Assurance, Context, Guard, Insight and Sentinel agents (choose which), with on-behalf-of sign-in from each agent through Foundry to Dataverse |
| [`conductor`](conductor) | The Conductor MCP server on its own, exposing Logic Blocks, Logic Flows and business processes as MCP tools |

The two templates are independent: deploy either or both, into the same resource group or
separate ones.

## How it fits together

```mermaid
flowchart LR
    user([User]) -->|signs in| agent[Agent<br/>Container App]
    agent -->|on-behalf-of token| foundry[Foundry MCP server<br/>Container App]
    foundry -->|on-behalf-of token| dataverse[(Dataverse)]
    agent --> redis[(Redis)]
    agent -->|prompts| llm[LLM provider]
    tools([MCP client]) -->|signs in| foundry
```

Every app authenticates as its own user-assigned managed identity through a federated
credential, so no client secret is created anywhere. Calls to Dataverse run as the signed-in
user, so each user's own Dataverse security roles apply.

## Getting started

### 1. Check the prerequisites

- An Azure subscription where you can create resource groups and resources.
- Permission to create Entra app registrations (Application Administrator, Cloud Application
  Administrator or equivalent).
- Global Administrator or Privileged Role Administrator to grant admin consent for the Dataverse
  permission. Without it, deploy with `grantAdminConsent` set to `false` and have an administrator
  grant consent in the Entra admin center afterwards.
- A Dataverse environment with the **LogicFabricComposer** solution imported. It ships the
  **Logic Fabric Author** security role the templates assign.
- System Administrator in that Dataverse environment, for the one-time setup in step 3.
- The latest [`azd`](https://aka.ms/azd-install) and [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli),
  and [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)
  for the setup script. [Azure Cloud Shell](https://shell.azure.com) has all three.

### 2. Get the templates

```bash
git clone https://github.com/flowon-official/logic-fabric-dataverse-azure.git
cd logic-fabric-dataverse-azure
```

To deploy a specific release, add `--branch <tag>` with a tag from the
[releases page](https://github.com/flowon-official/logic-fabric-dataverse-azure/releases).

### 3. Create the setup identity

The templates register each MCP server's managed identity as a Dataverse Application User. That
step runs as a separate *setup identity* that already holds System Administrator in Dataverse,
because a new identity can't grant itself access. Create it once per Dataverse environment and
reuse it for both templates and every later deployment:

```powershell
az login
./scripts/New-DataverseSetupIdentity.ps1 `
    -ResourceGroup logic-fabric-setup `
    -Location westeurope `
    -DataverseUrl https://your-org.crm.dynamics.com/
```

| Argument | Required | Description |
|---|---|---|
| `-ResourceGroup` | Yes | Resource group for the identity, created if it doesn't exist. Use a different one from your deployments: `azd down` deletes the deployment's resource group. |
| `-Location` | Yes | Azure region, e.g. `westeurope` |
| `-DataverseUrl` | Yes | URL of the Dataverse environment |
| `-Name` | No | Identity name. Default: `logic-fabric-dataverse-setup` |

Run it as a user who is a System Administrator in the Dataverse environment and who can create
managed identities in the resource group (Contributor or Managed Identity Contributor), or create
the resource group itself if it doesn't exist yet. The script creates the identity, adds it to
Dataverse as an Application User and assigns it System Administrator. It is safe to run again.

It finishes by printing the identity's resource ID. Keep it: it is the `setupManagedIdentityId`
parameter in the next step. To look it up later:

```bash
az identity show --resource-group logic-fabric-setup --name logic-fabric-dataverse-setup --query id --output tsv
```

### 4. Deploy

Each template is an `azd` project. Run these from the template's folder:

**Foundry and agents**

```bash
cd foundry
azd env new <environment-name>
azd env set dataverseUrl "https://your-org.crm.dynamics.com/"
azd env set setupManagedIdentityId "<resource ID from step 3>"
azd env set azureFoundryAnthropicEndpoint "https://<resource>.services.ai.azure.com/anthropic"
azd env set azureFoundryAnthropicModel "<deployment-name>"
azd env set azureFoundryAnthropicApiKey "<key>"
azd provision
```

**Conductor**

```bash
cd conductor
azd env new <environment-name>
azd env set dataverseUrl "https://your-org.crm.dynamics.com/"
azd env set setupManagedIdentityId "<resource ID from step 3>"
azd env set flowonProjects "Sales;Finance"
azd provision
```

The first `azd provision` asks for a subscription, region and resource group. When it finishes,
`azd env get-values` lists the outputs, such as the apps' URLs and Entra app IDs.

To deploy with the Azure CLI instead of azd, see *Deploy with the Azure CLI* in the
[Foundry](foundry/README.md#deploy-with-the-azure-cli) or
[Conductor](conductor/README.md#deploy-with-the-azure-cli) README.

### 5. Customize the deployment

Set parameters before running `azd provision`, and run it again whenever you change them:

- **Text values:** `azd env set <parameter> <value>`, e.g. `azd env set logLevel Information`.
- **Numbers, true/false, lists and objects:** edit `infra/main.parameters.json` in the template's
  folder, e.g. `"enabledAgents": { "value": ["assist", "guard"] }`.
- **With the Azure CLI:** edit `infra/deploy.bicepparam`, or add `--parameters <name>=<value>` to
  `az deployment group create`.

The parameters most deployments change:

| Parameter | Template | Purpose |
|---|---|---|
| `dataverseUrl` | both | Dataverse environment to connect to (required) |
| `setupManagedIdentityId` | both | Setup identity from step 3 (required) |
| `llmProvider` and its endpoint, model and key | foundry | LLM the agents use: Claude on Azure AI Foundry by default, or OpenAI models on Azure AI Foundry, other Azure AI Foundry models, OpenAI or Anthropic |
| `enabledAgents` | foundry | Which agents to deploy (default: all six) |
| `flowonProjects` | conductor | Flowon projects whose artifacts become MCP tools |
| `namePrefix` | both | Prefix for resource names (default `logic-fabric`) |
| `imageTag` | both | Container image version to run |
| `grantAdminConsent` | both | Set to `false` if you can't grant tenant-wide admin consent |
| `tags` | both | Tags applied to every Azure resource |
| `allowedIpRanges`, `network` | both | Restrict access by IP address, or integrate with a virtual network |
| `foundryCustomDomain`, `agentCustomDomains`, `customDomain` | per template | Custom domain names |

Every parameter, with its default and the allowed values, is listed in the template's README:
[Foundry parameters](foundry/README.md#parameters) and
[Conductor parameters](conductor/README.md#parameters).

## Versions

Releases are tagged `vMAJOR.MINOR.PATCH` and described in the [changelog](CHANGELOG.md). Deploy
from a release tag rather than `main`.

The container images are versioned separately on Docker Hub (`flowon/logic-fabric-dataverse-*`).
Each template pins an image tag through its `imageTag` parameter, so redeploying never upgrades
your apps by surprise. To upgrade, set a newer `imageTag` and provision again.

## Repository layout

```
foundry/      Foundry and agents template (azd project)
conductor/    Conductor template (azd project)
modules/      Bicep modules shared by both templates
scripts/      Setup helpers
```

## Validating changes

```bash
az bicep build --file foundry/infra/main.bicep
az bicep build --file conductor/infra/main.bicep
```

Pull requests also run the Bicep linter and [PSRule for Azure](https://azure.github.io/PSRule.Rules.Azure/)
(configured in [`ps-rule.yaml`](ps-rule.yaml)).

## Support and security

- Product documentation: [docs.flowon.com](https://docs.flowon.com)
- Template bugs: [open an issue](https://github.com/flowon-official/logic-fabric-dataverse-azure/issues)
- Vulnerabilities: see [SECURITY.md](SECURITY.md)

## License

[MIT](LICENSE). Portions are derived from
[Azure-Samples/azmcp-obo-template](https://github.com/Azure-Samples/azmcp-obo-template); see
[NOTICE.md](NOTICE.md).
