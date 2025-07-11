# Fix: Session Host Still Showing Domain Join Failed

## 🔴 Problem Identified
The issue was that `enableAzureADJoin` parameter was set to `$false` by default in the runbook, causing the Template Spec DSC extension to incorrectly configure `aadJoin: false` even when domain parameters were empty.

## ✅ Fix Applied
Changed the runbook parameter default from:
```powershell
[bool]$enableAzureADJoin = $false
```
To:
```powershell
[bool]$enableAzureADJoin = $true
```

## How This Works
The Template Spec logic:
```bicep
aadJoin: empty(domainToJoin) && enableAzureADJoin ? true : false
```

**Before Fix:**
- `domainToJoin = ""` (empty) ✅
- `enableAzureADJoin = false` ❌
- Result: `aadJoin: false` → DSC expects domain join → Fails

**After Fix:**
- `domainToJoin = ""` (empty) ✅
- `enableAzureADJoin = true` ✅
- Result: `aadJoin: true` → DSC expects Azure AD join → Success

## Verification Steps

### 1. Check Template Parameters Being Passed
Look for these values in your runbook deployment output:
```
domainToJoin = ""
enableAzureADJoin = True
```

### 2. Verify Extensions Deployed
After VM deployment, check in Azure Portal:

**Should Deploy:**
- ✅ `AADLoginForWindows` extension
- ✅ DSC extension with `aadJoin: true`

**Should NOT Deploy:**
- ❌ `JsonADDomainExtension` extension

### 3. Check DSC Extension Settings
In Azure Portal > VM > Extensions > DSC:
```json
{
  "properties": {
    "aadJoin": true,
    "hostPoolName": "YourHostPool",
    "registrationInfoToken": "..."
  }
}
```

### 4. Verify Session Host Status
In AVD Host Pool, session host should:
- ✅ Register successfully
- ✅ Show status "Available"
- ✅ No domain join errors

## Testing Commands

### PowerShell Test (Run these to verify)
```powershell
# Test with current parameters
$templateParams = @{
    domainToJoin = ""
    enableAzureADJoin = $true
}

# This should evaluate to true
$aadJoinResult = [string]::IsNullOrEmpty($templateParams.domainToJoin) -and $templateParams.enableAzureADJoin
Write-Output "aadJoin should be: $aadJoinResult"  # Should output: True
```

### Azure CLI Verification
```bash
# Check VM extensions
az vm extension list --resource-group "YourRG" --vm-name "YourVM" --query "[].{Name:name, Publisher:publisher, Type:typeHandlerVersion}" --output table

# Check session host status
az desktopvirtualization sessionhost list --host-pool-name "YourHostPool" --resource-group "YourRG" --query "[].{Name:name, Status:status}" --output table
```

## Next Steps

1. **Update Runbook Parameter**: If using Azure Automation, update the parameter value to `$true` in the runbook configuration

2. **Test Deployment**: Run the automation to rebuild a session host

3. **Monitor Results**: Check that:
   - VM gets Azure AD Join extension (not domain join)
   - Session host registers successfully
   - No domain join error messages

## Troubleshooting If Still Failing

### Check Template Spec Version
Ensure you're using the latest Template Spec version:
```powershell
Get-AzTemplateSpec -Name "YourTemplateSpecName" -ResourceGroupName "YourTemplateSpecRG" -Version "1.4"
```

### Check Network Connectivity
Azure AD join requires these endpoints:
- `login.microsoftonline.com`
- `device.login.microsoftonline.com`
- `enterpriseregistration.windows.net`

### Check Runbook Execution
Look for this output in runbook logs:
```
Processing Azure Compute Gallery image: /subscriptions/.../images/...
Template parameters for gallery image
domainToJoin = ""
enableAzureADJoin = True
```

## Validation Script
```powershell
# Run this on the deployed VM to verify Azure AD join
$computer = Get-ComputerInfo
Write-Output "Domain: $($computer.Domain)"
Write-Output "Workgroup: $($computer.Workgroup)"

# Check Azure AD join status
try {
    $aadStatus = Get-AzureADDevice -SearchString $env:COMPUTERNAME
    Write-Output "Azure AD Joined: $($aadStatus -ne $null)"
} catch {
    Write-Output "Azure AD PowerShell module not available"
}
```

The fix has been applied - your session hosts should now properly join Azure AD instead of attempting domain join!
