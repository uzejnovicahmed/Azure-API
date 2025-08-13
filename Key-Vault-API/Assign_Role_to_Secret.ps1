# Input Variables
$tenantId = "your-tenant-id"
$tenantname = "your-tenant-name"
$clientId = "your-client-id"
$clientSecret = "your-client-secret"
$subscriptionId = "your-subscription-id"
$resourceGroup  = "your-resource-group"

$vaultName = "your-vault-name"
$secretName = "your-secret-name"
$secretId = "your-secret-id"
$objectIdToGrant = "your-object-id"
$principalType = "User" # User,ServicePrincipal,Group

function Request-AccessToken {

    [CmdletBinding()]
    param (
        # The Microsoft Azure AD Tenant Name
        [Parameter(ParameterSetName = 'ClientAuth', Mandatory = $true)]  [string]$tenantid,
        # The Microsoft Azure AD TenantId (GUID or domain)
        [Parameter(ParameterSetName = 'ClientAuth', Mandatory = $true)]  [string]$ClientId,
        # An authentication secret of the Microsoft Azure AD Application Registration
        [Parameter(ParameterSetName = 'ClientAuth', Mandatory = $true)] [string]$ClientSecret,
        # The Scope
        [Parameter(ParameterSetName = 'ClientAuth', Mandatory = $false)] [string]$Scope
    )
      
    $resource = "https://graph.microsoft.com/"  
    
    $tokenBody = @{  
        Grant_Type    = 'client_credentials'  
        Scope         = $Scope  
        Client_Id     = $ClientId  
        Client_Secret = $clientSecret  
    }  
    
    try { $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantid/oauth2/v2.0/token" -Method POST -Body $tokenBody -ErrorAction Stop }catch { Throw "Error generating access token $($_)" }
    Write-Debug "Successfully generated authentication token"
    return $($tokenResponse.access_token)
}


try{

$token = Request-AccessToken -tenantid $tenantId -ClientId $clientId -ClientSecret $clientSecret -scope "https://management.azure.com/.default"

$headers = @{
    "Authorization" = "Bearer $($token)"
    "Content-type"  = "application/json;charset=utf-8"
}


# Assign RBAC Role to secret
$roleDefinitionId = "/subscriptions/$subscriptionId/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6" # Key Vault Secrets User

$resourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.KeyVault/vaults/$vaultName/secrets/$secretName"
$roleAssignmentId = (New-Guid).Guid

$roleAssignmentUrl = "https://management.azure.com$resourceId/providers/Microsoft.Authorization/roleAssignments/$($roleAssignmentId)?api-version=2022-04-01"

$bodymanager = @{
    properties = @{
        roleDefinitionId = $roleDefinitionId
        principalId      = $objectIdToGrant
        principalType    = $principalType
    }
}



$res = Invoke-RestMethod -Uri $roleAssignmentUrl -Method Put -Headers $headers -Body ($bodymanager | ConvertTo-Json -Depth 10)

if($res.properties.createdOn)
{
    $secretLink ="https://portal.azure.com/#@$($tenantname)/asset/Microsoft_Azure_KeyVault/Secret/$($secretid)"
    $status = "success"
}
else
{
    $status = "error"
    throw "Role assignment creation failed."
}

}
catch{
$status = "error"
$errormessage = $_ 
}
