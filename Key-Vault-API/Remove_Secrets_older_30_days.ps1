# Input Variables

$tenantId       = "your-tenant-id"
$clientId       = "your-client-id"
$clientSecret   = "your-client-secret"
$vaultName     = "your-vault-name"
[int]$deleteaftermonths = 1


$global:logWriter = $null
$Runbookname = "Purge secrets"
$Date = Get-Date -Format dd-MM-yyyy
$Logname = $Runbookname + "-" + $Date + ".log"
$Logpath = "your-log-path"
$Errormessages = @()
$result = 'success'

try{

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
    
    try { $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantid/oauth2/v2.0/token" -Method POST -Body $tokenBody -ErrorAction Stop }catch { return "Error generating access token $($_)" }
    Write-Debug "Successfully generated authentication token"
    return $($tokenResponse.access_token)
}


function Get-AzureResourcePaging {
    param (
        $URL,
        $AuthHeader
    )
 
    # List Get all Apps from Azure

    $Response = Invoke-RestMethod -Method GET -Uri $URL -Headers $AuthHeader
    $Resources = $Response.value

    $ResponseNextLink = $Response.nextLink
    while ($ResponseNextLink -ne $null) {

        $Response = (Invoke-RestMethod -Uri $ResponseNextLink -Headers $AuthHeader -Method Get)
        $ResponseNextLink = $Response.nextLink
        $Resources += $Response.value
    }

    if ($null -eq $Resources) {
        $Resources = $Response
    }

    return $Resources
}


function Write-PowerShellLog {
    param (
        [string]$logtext,
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG", "VERBOSE")]
        [string]$level = "INFO",
        [string]$logfile = $Logpath + $LogName
    )

    # Ensure log text is not empty or null
    if (![string]::IsNullOrWhiteSpace($logtext)) {
        $logdate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$logdate] - [$level] $logtext"
       
        # Check if the StreamWriter is already initialized
        if (-not $global:logWriter) {
            try {
                # Initialize StreamWriter in append mode
                $global:logWriter = [System.IO.StreamWriter]::new($logfile, $true)
            } catch {
                throw "Failed to create or open log file: $logfile"
                return
            }
        }

        # Append the log entry to the file
        try {
            $global:logWriter.WriteLine($logEntry)
            $global:logWriter.Flush() # Flush to make sure the log is written immediately
        } catch {
            Throw "Failed to write to log file: $logfile"
        }
    }
}




$token = Request-AccessToken -tenantid $tenantId -ClientId $clientId -ClientSecret $clientSecret -scope "https://vault.azure.net/.default"

$headers = @{
    "Authorization" = "Bearer $($token)"
    "Content-type"  = "application/json;charset=utf-8"
}
# -------------------
# Set the Secret
# -------------------

Write-PowerShellLog -logtext "Starting to remove secrets older than $deleteaftermonths month(s) from KeyVault $vaultName" -level "INFO"

$getsecretUrl = "https://$($vaultName).vault.azure.net/secrets?maxresults=1&api-version=7.4"

$response = $null

$response = Get-AzureResourcePaging -URL $getsecretUrl -AuthHeader $headers

Write-PowerShellLog -logtext "Retrieved $($response.Count) secrets from KeyVault $vaultName" -level "INFO"



foreach($secret in $response) {
    
    try{
    $timestamp = $null
    $convertedtime = $null
    $timestamp = $secret.attributes.created
    $convertedtime = [DateTimeOffset]::FromUnixTimeSeconds($timestamp).LocalDateTime
    #if time is 1month old write into a to delete array
    if ($convertedtime -lt (Get-Date).AddMonths(-$deleteaftermonths)) {
        
        Write-PowerShellLog -logtext "Secret $($secret.id) is older than $deleteaftermonths month(s) ($($convertedtime)) and will be deleted." -level "INFO"

        $deleteurl = $null
        $deleteurl = "$($secret.id)?api-version=7.4"
        $result = Invoke-RestMethod -Method Delete -URI $deleteurl -headers $headers
        Write-PowerShellLog -logtext "Removed Secret $($secret.id) from KeyVault $($vaultName)." -level "INFO"
        Write-PowerShellLog -logtext "Recoveryid of Secret $($secret.id) is $($result.recoveryId)." -level "INFO"
        Write-PowerShellLog -logtext "---------------------------------------------------------" -level "INFO"

    } 

}
    catch {
        Write-PowerShellLog -logtext "An error occurred while processing secret $($secret.id): $($_.Exception.Message)" -level "ERROR"
        Write-PowerShellLog -logtext "----------------------------------------------------------" -level "INFO"
        $errormessages += "An error occurred while processing secret $($secret.id): $($_.Exception.Message)"
        $result = 'error'
    }

}

}
catch{
    $Errormessages += "An error occurred: $($_.Exception.Message)"
    $result = 'error'
    Write-PowerShellLog -logtext "An error occurred: $($_.Exception.Message)" -level "ERROR"
    Throw "An error occurred: $($_)"
}

Write-PowerShellLog -logtext "End Script" -level "INFO"


$result
$Errormessages
