# Copyright (c) 2026 Flowon Corp. Licensed under the MIT License.

<#
.SYNOPSIS
    Creates the setup managed identity the Logic Fabric templates need and makes it a Dataverse
    System Administrator.

.DESCRIPTION
    The templates register each server's managed identity as a Dataverse Application User. That
    step runs as a separate, pre-existing identity holding System Administrator in Dataverse,
    because a new identity cannot grant itself access. This script creates that identity (once per
    Dataverse environment) and grants it the role.

    Run it signed in to the Azure CLI (`az login`) as a user who can create managed identities in
    the target resource group and who is a System Administrator in the Dataverse environment.
    It is safe to re-run.

.EXAMPLE
    ./New-DataverseSetupIdentity.ps1 -ResourceGroup logic-fabric-setup -Location westeurope `
        -DataverseUrl https://contoso.crm.dynamics.com/
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ResourceGroup,

    [Parameter(Mandatory)]
    [string] $Location,

    [Parameter(Mandatory)]
    [string] $DataverseUrl,

    [string] $Name = 'logic-fabric-dataverse-setup'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

# Template ID of the built-in System Administrator role; the same in every Dataverse environment.
$systemAdministratorTemplateId = '627090ff-40a3-4053-8790-584edc5be201'

$base = $DataverseUrl.TrimEnd('/')
$api = "$base/api/data/v9.2"

if ((az group exists --name $ResourceGroup) -ne 'true') {
    Write-Host "Creating resource group $ResourceGroup..."
    az group create --name $ResourceGroup --location $Location --output none
}

Write-Host "Creating managed identity $Name..."
$identity = az identity create --name $Name --resource-group $ResourceGroup --location $Location | ConvertFrom-Json

$token = az account get-access-token --resource $base --query accessToken --output tsv
$headers = @{
    Authorization      = "Bearer $token"
    'OData-MaxVersion' = '4.0'
    'OData-Version'    = '4.0'
    Accept             = 'application/json'
}

function Invoke-Dataverse([string] $Method, [string] $Path, $Body) {
    $request = @{ Method = $Method; Uri = "$api/$Path"; Headers = $headers }
    if ($null -ne $Body) {
        $request.Body = $Body | ConvertTo-Json -Compress
        $request.ContentType = 'application/json'
    }
    Invoke-RestMethod @request
}

$rootBusinessUnitId = (Invoke-Dataverse GET 'businessunits?$filter=parentbusinessunitid eq null&$select=businessunitid').value[0].businessunitid

$role = (Invoke-Dataverse GET "roles?`$filter=_roletemplateid_value eq $systemAdministratorTemplateId and _businessunitid_value eq $rootBusinessUnitId&`$select=roleid").value[0]
if (-not $role) { throw "System Administrator role not found in $DataverseUrl." }

$userQuery = "systemusers?`$filter=applicationid eq '$($identity.clientId)'&`$select=systemuserid"
$user = (Invoke-Dataverse GET $userQuery).value[0]
if (-not $user) {
    Write-Host 'Creating the Dataverse Application User...'
    # A new identity's service principal can take a minute to reach Dataverse, so retry.
    for ($attempt = 1; ; $attempt++) {
        try {
            Invoke-Dataverse POST 'systemusers' @{
                applicationid                = $identity.clientId
                'businessunitid@odata.bind' = "/businessunits($rootBusinessUnitId)"
            } | Out-Null
            break
        }
        catch {
            if ($attempt -ge 6) { throw }
            Write-Host "  Not ready yet ($($_.Exception.Message)); retrying in 20 seconds..."
            Start-Sleep -Seconds 20
        }
    }
    $user = (Invoke-Dataverse GET $userQuery).value[0]
}

$assigned = (Invoke-Dataverse GET "systemusers($($user.systemuserid))/systemuserroles_association?`$filter=roleid eq $($role.roleid)&`$select=roleid").value
if (-not $assigned) {
    Write-Host 'Assigning System Administrator...'
    Invoke-Dataverse POST "systemusers($($user.systemuserid))/systemuserroles_association/`$ref" @{
        '@odata.id' = "$api/roles($($role.roleid))"
    } | Out-Null
}

Write-Host ''
Write-Host 'Done. Pass this resource ID as setupManagedIdentityId:'
Write-Host "  $($identity.id)"
Write-Host ''
Write-Host 'With azd:'
Write-Host "  azd env set setupManagedIdentityId `"$($identity.id)`""
