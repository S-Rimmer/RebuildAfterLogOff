# Simple Step-by-Step Commands to Grant Device.ReadWrite.All Permission

## Use these exact commands in PowerShell (run as Administrator):

### Step 1: Install Microsoft Graph module
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser -Force
```

### Step 2: Connect to Microsoft Graph
```powershell
Connect-MgGraph -Scopes "Application.ReadWrite.All", "AppRoleAssignment.ReadWrite.All"
```

### Step 3: Replace "YourAutomationAccountName" with your actual Automation Account name and run these commands:
```powershell
# Set your Automation Account name
$automationAccountName = "YourAutomationAccountName"  # REPLACE THIS

# Get your Automation Account's managed identity
$managedIdentity = Get-MgServicePrincipal -Filter "DisplayName eq '$automationAccountName'"

# Get Microsoft Graph service principal
$graphSP = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"

# Find Device.ReadWrite.All permission
$devicePermission = $graphSP.AppRoles | Where-Object { $_.Value -eq "Device.ReadWrite.All" }

# Create the permission assignment
$body = @{
    principalId = $managedIdentity.Id
    resourceId = $graphSP.Id
    appRoleId = $devicePermission.Id
}

# Assign the permission
New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentity.Id -BodyParameter $body
```

### Step 4: Verify the assignment worked
```powershell
# Check if permission was assigned
Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentity.Id | Where-Object { $_.AppRoleId -eq $devicePermission.Id }
```

### Expected Success Output:
You should see output similar to:
```
Id                                          AppRoleId                            CreatedDateTime
--                                          ---------                            ---------------
abc123-def4-567g-890h-ijklmnop12345        1138cb37-bd11-4084-a2b7-9f71582aeddb 7/17/2025 10:30:00 AM
```

## Alternative: Run the automated script
```powershell
.\Grant-AutomationDevicePermissions.ps1 -AutomationAccountName "YourAutomationAccountName"
```

## What this does:
✅ Grants Device.ReadWrite.All permission to your Automation Account's managed identity
✅ Allows your runbook to delete Azure AD devices that cause hostname conflicts
✅ Prevents "A device with the same name already exists in Azure AD" errors
✅ Enables automatic cleanup of old/orphaned AVD session host registrations

## Requirements:
- You must have **Global Administrator** or **Privileged Role Administrator** permissions
- Your Automation Account must have **system-assigned managed identity** enabled
- PowerShell must be run with administrator privileges
