# Quick Command to Grant Device.ReadWrite.All Permission
# Run this in PowerShell with appropriate admin permissions

# METHOD 1: Using Microsoft Graph PowerShell (RECOMMENDED)
# Step 1: Install Microsoft Graph module if not already installed
Install-Module Microsoft.Graph -Scope CurrentUser -Force

# Step 2: Connect to Microsoft Graph
Connect-MgGraph -Scopes "Application.ReadWrite.All", "AppRoleAssignment.ReadWrite.All"

# Step 3: Run these commands (replace with your actual values)
$automationAccountName = "YourAutomationAccountName"

# Get your Automation Account's managed identity
$managedIdentity = Get-MgServicePrincipal -Filter "DisplayName eq '$automationAccountName'"

# Get Microsoft Graph service principal
$graphSP = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"

# Find Device.ReadWrite.All permission
$devicePermission = $graphSP.AppRoles | Where-Object { $_.Value -eq "Device.ReadWrite.All" }

# Assign the permission
$body = @{
    principalId = $managedIdentity.Id
    resourceId = $graphSP.Id
    appRoleId = $devicePermission.Id
}
New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentity.Id -BodyParameter $body

# METHOD 2: Using Az PowerShell (Alternative if Method 1 doesn't work)
# Step 1: Connect to Azure
Connect-AzAccount

# Step 2: Get your Automation Account's managed identity
$automationAccountName = "YourAutomationAccountName"
$managedIdentity = Get-AzADServicePrincipal -DisplayName $automationAccountName

# Step 3: Use REST API call (since New-AzADAppRoleAssignment might not be available)
$resourceId = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
$appRoleId = "1138cb37-bd11-4084-a2b7-9f71582aeddb" # Device.ReadWrite.All

$body = @{
    principalId = $managedIdentity.Id
    resourceId = (Get-AzADServicePrincipal -Filter "AppId eq '$resourceId'").Id
    appRoleId = $appRoleId
} | ConvertTo-Json

$headers = @{
    'Authorization' = "Bearer $((Get-AzAccessToken).Token)"
    'Content-Type' = 'application/json'
}

$uri = "https://graph.microsoft.com/v1.0/servicePrincipals/$($managedIdentity.Id)/appRoleAssignments"
Invoke-RestMethod -Uri $uri -Method POST -Body $body -Headers $headers

# Expected output:
# ✅ Successfully assigned Device.ReadWrite.All permission!
