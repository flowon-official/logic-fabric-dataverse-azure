// Copyright (c) 2026 Flowon Corp. Licensed under the MIT License.
//
// Creates (or finds) a Dataverse Application User for a client ID and assigns it a security role.
// Dataverse has no ARM or Microsoft Graph resource type for this, so it is a deployment script
// calling the Dataverse Web API through `az rest` (the azure-cli image does not reliably ship curl).
//
// The script runs as `identityId`, which must already hold System Administrator (or equivalent) in
// the target Dataverse environment: a new identity cannot grant itself access. See
// scripts/New-DataverseSetupIdentity.ps1.
//
// The script is idempotent and re-runs on every deployment, so it repairs an Application User or
// role assignment removed out of band. Azure deletes the script's temporary storage account and
// container instance on success, and keeps them for a day after a failure for debugging.

@description('Location for all resources')
param location string = resourceGroup().location

@description('Name of the deployment script resource')
param name string

@description('URL of the Dataverse environment, e.g. https://your-org.crm.dynamics.com/')
param dataverseUrl string

@description('Client ID of the app registration or managed identity to create as an Application User')
param applicationClientId string

@description('ID of the security role to assign, as shipped in its solution. Looked up by ID so renaming the role does not break deployment.')
param securityRoleId string

@description('Resource ID of the user-assigned managed identity the script runs as')
param identityId string

@description('Tags applied to the deployment script')
param tags object = {}

@description('Forces the script to re-run on every deployment')
param forceUpdateTag string = utcNow()

resource dataverseApplicationUserSetup 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: name
  location: location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    azCliVersion: '2.61.0'
    forceUpdateTag: forceUpdateTag
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    timeout: 'PT10M'
    environmentVariables: [
      {
        name: 'DATAVERSE_URL'
        value: dataverseUrl
      }
      {
        name: 'APP_CLIENT_ID'
        value: applicationClientId
      }
      {
        name: 'ROLE_SOLUTION_ID'
        value: securityRoleId
      }
    ]
    scriptContent: '''
      set -euo pipefail

      BASE="${DATAVERSE_URL%/}"
      API="$BASE/api/data/v9.2"
      ODATA_HEADERS=(--headers "OData-MaxVersion=4.0" "OData-Version=4.0" "Accept=application/json")

      echo "Looking up root business unit..."
      ROOT_BU_ID=$(az rest --method get --resource "$BASE" "${ODATA_HEADERS[@]}" \
        --url "$API/businessunits?\$filter=parentbusinessunitid eq null&\$select=businessunitid" \
        --query "value[0].businessunitid" -o tsv)
      if [ -z "$ROOT_BU_ID" ] || [ "$ROOT_BU_ID" = "None" ]; then
        echo "Could not determine the root business unit." >&2
        exit 1
      fi

      # Matched by id, not name, so renaming the role in its solution doesn't break this lookup. The
      # root business unit's copy of a solution role keeps the solution's role id; copies in other
      # business units get their own roleid and point back at it through parentrootroleid, so both
      # are matched and then narrowed to the root business unit.
      ROLE_SOLUTION_ID="${ROLE_SOLUTION_ID//[\{\}]/}"
      echo "Looking up security role $ROLE_SOLUTION_ID..."
      ROLE_ID=$(az rest --method get --resource "$BASE" "${ODATA_HEADERS[@]}" \
        --url "$API/roles?\$filter=(roleid eq $ROLE_SOLUTION_ID or _parentrootroleid_value eq $ROLE_SOLUTION_ID) and _businessunitid_value eq $ROOT_BU_ID&\$select=roleid" \
        --query "value[0].roleid" -o tsv)
      if [ -z "$ROLE_ID" ] || [ "$ROLE_ID" = "None" ]; then
        echo "Security role $ROLE_SOLUTION_ID was not found in business unit $ROOT_BU_ID. Import the solution that ships it first." >&2
        exit 1
      fi
      ROLE_NAME=$(az rest --method get --resource "$BASE" "${ODATA_HEADERS[@]}" \
        --url "$API/roles($ROLE_ID)?\$select=name" \
        --query "name" -o tsv)
      echo "Found security role '$ROLE_NAME' (roleid=$ROLE_ID)."

      echo "Looking up existing Application User for client id $APP_CLIENT_ID..."
      SYSTEM_USER_ID=$(az rest --method get --resource "$BASE" "${ODATA_HEADERS[@]}" \
        --url "$API/systemusers?\$filter=applicationid eq '$APP_CLIENT_ID'&\$select=systemuserid" \
        --query "value[0].systemuserid" -o tsv)

      if [ -z "$SYSTEM_USER_ID" ] || [ "$SYSTEM_USER_ID" = "None" ]; then
        echo "No existing Application User found — creating one..."
        az rest --method post --resource "$BASE" "${ODATA_HEADERS[@]}" \
          --url "$API/systemusers" \
          --body "{\"applicationid\": \"$APP_CLIENT_ID\", \"businessunitid@odata.bind\": \"/businessunits($ROOT_BU_ID)\"}" \
          --output none

        SYSTEM_USER_ID=$(az rest --method get --resource "$BASE" "${ODATA_HEADERS[@]}" \
          --url "$API/systemusers?\$filter=applicationid eq '$APP_CLIENT_ID'&\$select=systemuserid" \
          --query "value[0].systemuserid" -o tsv)
      else
        echo "Application User already exists (systemuserid=$SYSTEM_USER_ID)."
      fi

      if [ -z "$SYSTEM_USER_ID" ] || [ "$SYSTEM_USER_ID" = "None" ]; then
        echo "Failed to create or find the Application User's systemuserid." >&2
        exit 1
      fi

      echo "Checking whether the role is already assigned..."
      ALREADY_ASSIGNED_COUNT=$(az rest --method get --resource "$BASE" "${ODATA_HEADERS[@]}" \
        --url "$API/systemusers($SYSTEM_USER_ID)/systemuserroles_association?\$filter=roleid eq $ROLE_ID&\$select=roleid" \
        --query "length(value)" -o tsv)

      if [ "$ALREADY_ASSIGNED_COUNT" = "0" ]; then
        echo "Assigning role '$ROLE_NAME' to the Application User..."
        az rest --method post --resource "$BASE" "${ODATA_HEADERS[@]}" \
          --url "$API/systemusers($SYSTEM_USER_ID)/systemuserroles_association/\$ref" \
          --body "{\"@odata.id\": \"$API/roles($ROLE_ID)\"}" \
          --output none
      else
        echo "Role already assigned."
      fi

      echo "{\"systemUserId\": \"$SYSTEM_USER_ID\", \"roleId\": \"$ROLE_ID\"}" > "$AZ_SCRIPTS_OUTPUT_PATH"
    '''
  }
}

output systemUserId string = dataverseApplicationUserSetup.properties.outputs.systemUserId
output roleId string = dataverseApplicationUserSetup.properties.outputs.roleId
