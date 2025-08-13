# Input Variables
$tenantId       = "your-tenant-id"
$clientId       = "your-client-id"
$clientSecret   = "your-client-secret"

$vaultName      = "your-vault-name"
$secretName     = "your-secret-name"
$secretValue    = "your-secret-value"


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
    
    try { $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantid/oauth2/v2.0/token" -Method POST -Body $tokenBody -ErrorAction Stop }catch { throw "Error generating access token $($_)" }
    Write-Debug "Successfully generated authentication token"
    return $($tokenResponse.access_token)
}


try{

$token = Request-AccessToken -tenantid $tenantId -ClientId $clientId -ClientSecret $clientSecret -scope "https://vault.azure.net/.default"


$headers = @{
    "Authorization" = "Bearer $($token)"
    "Content-type"  = "application/json;charset=utf-8"
}

# -------------------
# Set the Secret
# -------------------


if(![string]::IsNullOrEmpty($secretName))
{
$secretUrl = "https://$($vaultName).vault.azure.net/secrets/$($secretName)?api-version=7.4"
$secretBody = @{
    value = $secretValue
} | ConvertTo-Json

$response = $null
$response = Invoke-RestMethod -Method Put -Uri $secretUrl -Headers $headers -Body $secretBody -ErrorAction stop
$secretid = $response.id
$status = "success"
}else{
Throw "No secretname was provided"
}

}
catch
{

$status = "error"
$errormessage = $_

}

$secretid
$status
$errormessage
