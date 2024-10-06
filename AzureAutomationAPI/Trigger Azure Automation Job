# Azure AD Anwendungsinformationen
$tenantId = "mytenantid"
$clientId = "myclientid"
$clientSecret = "myclientsecret"
$resource = "https://management.azure.com/"

# Azure Ressourceninformationen
$subscriptionId = "mysubscriptionid"
$resourceGroupName = "MYDEMOAAACOUNTNAME"
$automationAccountName = "MYDEMOAAACOUNTNAME"
$runbookName = "RB_00_Trigger_From_PS_API"
$apiVersion = "2017-05-15-preview"  # Updated API version


# Runbook parameters

$runbookParameters = @{
    "Displayname" = "Uzejnovic Ahmed"
    "Firstname" = "Ahmed"
    "Lastname" = "Uzejnovic"
}

# Authenticate with Azure AD
$authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/token"

$authBody = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    resource      = $resource
}

$response = Invoke-RestMethod -Method Post -Uri $authUrl -Body $authBody
$accessToken = $response.access_token

# Request headers
$headers = @{
    Authorization = "Bearer $accessToken"
    "Content-Type"  = "application/json"
}

# Generate a unique job ID
$jobId = (New-Guid).Guid

# Base URL for the job
$jobBaseUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Automation/automationAccounts/$automationAccountName/jobs/$jobId"

# Build the job URL with api-version

$jobUrl = $jobBaseUrl + "?api-version=$apiVersion"

# Prepare the request body with properties at the root level
$jobBodyObject = @{
    properties = @{
        runbook = @{
            name = $runbookName
        }
        parameters = $runbookParameters
    }
}

# Convert the body to JSON
$jobBody = $jobBodyObject | ConvertTo-Json -Depth 10

# Output the JSON for debugging purposes
Write-Output "Request Body:"
Write-Output $jobBody

# Start the Runbook job using PUT
$jobResponse = Invoke-RestMethod -Method Put -Uri $jobUrl -Headers $headers -Body $jobBody

Write-Output "Runbook started. Job ID: $jobId"

# Poll the job status
$jobCompleted = $false

while (-not $jobCompleted) {
    
    $jobStatusResponse = Invoke-RestMethod -Method Get -Uri $jobUrl -Headers $headers
    
    $status = $jobStatusResponse.properties.status
    
    Write-Output "Current job status: $status"

    switch ($status) {
        "Completed" { $jobCompleted = $true }
        "Failed"    { $jobCompleted = $true }
        "Stopped"   { $jobCompleted = $true }
        Default     {
            Start-Sleep -Seconds 10
        }
    }
}

Write-Output "Runbook completed with status: $status `n"

$outputUrl = $jobBaseUrl + "/streams?api-version=2017-05-15-preview"

# Retrieve the output

$outputResponse = Invoke-RestMethod -Method Get -Uri $outputUrl -Headers $headers

# Filter and process the output streams

$outputStreams = $outputResponse.value | Where-Object { $_.properties.streamType -eq "Output" }
$outputContent = $outputStreams | ForEach-Object { $_.properties.summary } | Out-String

Write-Output $outputContent

