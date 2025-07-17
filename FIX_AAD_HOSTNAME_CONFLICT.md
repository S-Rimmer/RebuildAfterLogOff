# URGENT FIX: Azure AD Hostname Conflict Error

## 🐛 Issue Identified
```
AAD Join failed with status code: -2145648509. The hostname is already used by another device in this tenant, please change the VM name to redeploy the extension.
```

**Root Cause:** When your runbook rebuilds VMs, it removes the VM from Azure but doesn't clean up the Azure AD device registration. When redeploying with the same VM name, Azure AD sees a duplicate hostname.

## 🚨 IMMEDIATE FIX (Choose One Option)

### Option 1: Clean Up Azure AD Device (Recommended)
```powershell
# Run the cleanup script for your specific VM
.\Clean-AADDevices.ps1 -DeviceName "YourFailedVMName"

# Or clean up all devices for your host pool
.\Clean-AADDevices.ps1 -HostPoolName "YourHostPool" -ResourceGroupName "YourAVDRG"
```

### Option 2: Manual Azure AD Cleanup
```powershell
# Connect to Azure and get access token
$accessToken = (Get-AzAccessToken).Token
$headers = @{ 'Authorization' = "Bearer $accessToken"; 'Content-Type' = 'application/json' }

# Find the device
$deviceName = "YourVMName"  # Replace with actual VM name
$devicesUri = "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$deviceName'"
$devices = Invoke-RestMethod -Uri $devicesUri -Headers $headers -Method Get

# Remove the device
if ($devices.value) {
    $deleteUri = "https://graph.microsoft.com/v1.0/devices/$($devices.value[0].id)"
    Invoke-RestMethod -Uri $deleteUri -Headers $headers -Method Delete
    Write-Output "Device removed: $deviceName"
}
```

### Option 3: Use Different VM Name (Quick Fix)
Modify your VM naming to include a timestamp:
```powershell
# In your runbook, change the VM name generation
$hostName = "$($originalHostName)-$(Get-Date -Format 'MMddHHmm')"
```

## ✅ LONG-TERM FIX: Updated Runbook

I've updated your runbook to automatically clean up Azure AD device registrations during the VM replacement process. The updated `Replace-AvdHost` function now includes:

### New Azure AD Cleanup Step
```powershell
# Clean up Azure AD device registration to prevent hostname conflicts
Write-Output "...Cleaning up Azure AD device registration"
try {
    # Get the short name for Azure AD device lookup
    $deviceName = ($hostName -split "\.")[0]  # Get short name without FQDN
    
    # Try to find and remove the Azure AD device
    $accessToken = (Get-AzAccessToken).Token
    $headers = @{
        'Authorization' = "Bearer $accessToken"
        'Content-Type' = 'application/json'
    }
    
    # Get devices with matching display name
    $devicesUri = "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$deviceName'"
    $devices = Invoke-RestMethod -Uri $devicesUri -Headers $headers -Method Get -ErrorAction SilentlyContinue
    
    if ($devices.value -and $devices.value.Count -gt 0) {
        foreach ($device in $devices.value) {
            Write-Output "...Found Azure AD device: $($device.displayName) (ID: $($device.id))"
            $deleteUri = "https://graph.microsoft.com/v1.0/devices/$($device.id)"
            try {
                Invoke-RestMethod -Uri $deleteUri -Headers $headers -Method Delete -ErrorAction Stop
                Write-Output "...Successfully removed Azure AD device: $($device.displayName)"
            }
            catch {
                Write-Output "...Warning: Could not remove Azure AD device $($device.displayName): $($_.Exception.Message)"
            }
        }
    }
    else {
        Write-Output "...No Azure AD device found with name: $deviceName"
    }
}
catch {
    Write-Output "...Warning: Azure AD device cleanup failed (non-blocking): $($_.Exception.Message)"
    Write-Output "...This may cause hostname conflicts during Azure AD join. Consider manual cleanup if deployment fails."
}
```

## 📋 Required Permissions

The runbook needs these Microsoft Graph permissions to clean up Azure AD devices:

### Managed Identity Permissions
Your Automation Account's managed identity needs:
- **Device.ReadWrite.All** - To read and delete Azure AD devices
- **Directory.ReadWrite.All** - Alternative broader permission

### Grant Permissions (PowerShell)
```powershell
# Connect as Global Admin
Connect-AzureAD

# Get the managed identity
$managedIdentity = Get-AzureADServicePrincipal -Filter "displayName eq 'YourAutomationAccountName'"

# Get Microsoft Graph service principal
$graphSP = Get-AzureADServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"

# Find the Device.ReadWrite.All role
$deviceRole = $graphSP.AppRoles | Where-Object {$_.Value -eq "Device.ReadWrite.All"}

# Grant the permission
New-AzureADServiceAppRoleAssignment -ObjectId $managedIdentity.ObjectId -PrincipalId $managedIdentity.ObjectId -ResourceId $graphSP.ObjectId -Id $deviceRole.Id
```

## 🧪 Testing Your Fix

### Test Azure AD Cleanup Script
```powershell
# Test with list-only mode first
.\Clean-AADDevices.ps1 -HostPoolName "YourHostPool" -ResourceGroupName "YourAVDRG" -ListOnly

# If devices are found, clean them up
.\Clean-AADDevices.ps1 -HostPoolName "YourHostPool" -ResourceGroupName "YourAVDRG" -Force
```

### Test VM Deployment
1. Clean up any existing Azure AD devices
2. Wait 5-10 minutes for replication
3. Run your runbook to rebuild a VM
4. Verify successful Azure AD join

## 🔍 Troubleshooting

### If Cleanup Script Fails
Check permissions:
```powershell
# Test Graph API access
$accessToken = (Get-AzAccessToken).Token
$headers = @{ 'Authorization' = "Bearer $accessToken" }
$testUri = "https://graph.microsoft.com/v1.0/me"
Invoke-RestMethod -Uri $testUri -Headers $headers -Method Get
```

### If VM Still Fails to Join
1. **Verify device is removed:** Check Azure AD > Devices in portal
2. **Wait for replication:** Azure AD changes can take 5-10 minutes
3. **Check VM name:** Ensure you're not reusing a name too quickly
4. **Verify network connectivity:** VM must reach Azure AD endpoints

### Common Error Codes
- **-2145648509 (0x801c0083):** Hostname already exists (this fix addresses this)
- **-2145648508 (0x801c0084):** Device limit exceeded
- **-2145648507 (0x801c0085):** Device enrollment not allowed

## 📊 Deployment Process with Fix

### Updated VM Replacement Flow
1. ✅ Remove session host from AVD
2. ✅ Stop and remove VM, NIC, and disk
3. 🆕 **Clean up Azure AD device registration**
4. ✅ Create new VM with same name
5. ✅ Azure AD join succeeds (no hostname conflict)
6. ✅ AVD agent installation and registration
7. ✅ Health checks pass

## 🎯 Prevention Strategy

The updated runbook prevents this issue by:
- **Proactive cleanup:** Removes Azure AD devices during VM removal
- **Graceful handling:** Non-blocking operation that warns if cleanup fails
- **Minimal permissions:** Uses Microsoft Graph API with least required permissions
- **Logging:** Clear output showing cleanup status

This should completely resolve your hostname conflict issues during Azure AD join while maintaining the automated rebuilding functionality of your runbook.
