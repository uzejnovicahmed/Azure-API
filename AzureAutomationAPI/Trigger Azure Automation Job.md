
# Azure Automation Runbook Execution Guide

## Introduction

This guide provides step-by-step instructions on how to use a PowerShell script to trigger an Azure Automation Runbook using Azure REST API. We will explore each step from setting up authentication to retrieving the execution output of the runbook.

---

## Prerequisites

Before starting, ensure that you have the following:

1. **Azure Subscription**: You need a valid Azure subscription.
2. **Azure Automation Account**: The Automation account should already be created.
3. **Azure AD Application**: An Azure AD application with the necessary permissions to access the Automation account and execute runbooks.
4. **PowerShell Environment**: Ensure that PowerShell is installed and configured on your local machine.

---

## Step 1: Define Azure AD Application Information

To authenticate against the Azure AD and interact with the Azure REST API, we need to define the Azure AD application details:

```powershell
# Azure AD Application Information
$tenantId = "mytenantid"
$clientId = "myclientid"
$clientSecret = "myclientsecret"
$resource = "https://management.azure.com/"
```
- **`$tenantId`**: The Azure Active Directory tenant ID.
- **`$clientId`**: The client ID of the registered Azure AD application.
- **`$clientSecret`**: The client secret for the Azure AD application.
- **`$resource`**: The resource URI that the token is requested for (in this case, Azure Management API).

---

## Step 2: Define Azure Resource Information

Define details about the Azure resources where the automation account and runbook are located:

```powershell
# Azure Resource Information
$subscriptionId = "mysubscriptionid"
$resourceGroupName = "MYDEMOAAACOUNTNAME"
$automationAccountName = "MYDEMOAAACOUNTNAME"
$runbookName = "RB_00_Trigger_From_PS_API"
$apiVersion = "2017-05-15-preview"  # API version for Azure Automation
```
- **`$subscriptionId`**: The ID of the Azure subscription.
- **`$resourceGroupName`**: The name of the resource group containing the Automation account.
- **`$automationAccountName`**: The name of the Automation account.
- **`$runbookName`**: The name of the runbook to be executed.

---

## Step 3: Define Runbook Parameters

Specify the parameters required for the runbook:

```powershell
# Runbook parameters
$runbookParameters = @{
    "Displayname" = "Uzejnovic Ahmed"
    "Firstname" = "Ahmed"
    "Lastname" = "Uzejnovic"
}
```
These parameters will be passed to the runbook during execution.

---

## Step 4: Authenticate with Azure AD

Use the Azure AD application details to authenticate and retrieve an access token:

```powershell
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
```
The access token will be used in subsequent API calls to interact with the Azure Automation service.

---

## Step 5: Start the Runbook

Trigger the runbook using a `PUT` request. This request will start the runbook job:

```powershell
# Generate a unique job ID
$jobId = (New-Guid).Guid

# Base URL for the job
$jobBaseUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Automation/automationAccounts/$automationAccountName/jobs/$jobId"

# Build the job URL with API version
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
```

The unique job ID will be used to track and monitor the runbook's execution.

---

## Step 6: Monitor the Runbook Execution

Poll the job status until it completes:

```powershell
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
```

This script will check the job status every 10 seconds until the runbook status is either `Completed`, `Failed`, or `Stopped`.

---

## Step 7: Retrieve the Runbook Output

After the runbook completes, retrieve the output:

```powershell
# Retrieve the output
$outputUrl = $jobBaseUrl + "/streams?api-version=2017-05-15-preview"

$outputResponse = Invoke-RestMethod -Method Get -Uri $outputUrl -Headers $headers

# Filter and process the output streams
$outputStreams = $outputResponse.value | Where-Object { $_.properties.streamType -eq "Output" }
$outputContent = $outputStreams | ForEach-Object { $_.properties.summary } | Out-String

Write-Output $outputContent
```

This step captures the output of the runbook and filters for the streams of type `Output`.

---

## Example Execution Output

The following is an example of what you can expect from executing this guide:

```
Runbook started. Job ID: 8e979eeb-1a4e-40bb-af8a-b97014749cd6

Current job status: New
Current job status: New
Current job status: Activating
Current job status: Activating
Current job status: Completed

Runbook completed with status: Completed

{
    "Displayname":  "processed",
    "Firstname":  "processed",
    "Lastname":  "processed"
}
```

This indicates that the runbook has successfully executed and returned the processed output.

---
