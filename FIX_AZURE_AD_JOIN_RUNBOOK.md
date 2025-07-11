# Fix: Azure AD Join Issues - VMs Attempting Domain Join Instead

## Problem
After updating the Template Spec, VMs are no longer Azure AD (Entra ID) joined and showing "domain joined failed" errors, indicating they are incorrectly trying to join an Active Directory domain instead of Azure AD.

## Root Cause
The runbook was not explicitly passing the domain join parameters to the Template Spec. When these parameters are missing or have unexpected values, the Template Spec logic incorrectly attempts domain join instead of Azure AD join.

## Solution Applied

### 1. Updated Runbook Parameters
The runbook now explicitly passes empty domain join parameters to force Azure AD join behavior:

```powershell
# Domain join parameters - explicitly set to empty for Azure AD join
domainToJoin = ""
ouPath = ""
domainUsername = ""
domainPassword = ""
```

### 2. Template Spec Logic Verification
The Template Spec uses this logic to determine join type:

```bicep
// Domain join extension (only if domainToJoin is NOT empty)
resource domainJoinExtension = if (!empty(domainToJoin)) {
  // ... domain join configuration
}

// Azure AD join extension (only if domainToJoin IS empty AND enableAzureADJoin is true)
resource aadJoinExtension = if (empty(domainToJoin) && enableAzureADJoin) {
  // ... Azure AD join configuration
}

// DSC extension aadJoin parameter
aadJoin: empty(domainToJoin) && enableAzureADJoin ? true : false
```

## Verification Steps

### 1. Check Template Deployment Parameters
In your runbook output, look for the template parameters being passed:
- `domainToJoin` should be empty string `""`
- `enableAzureADJoin` should be `true`
- `aadJoin` in DSC extension should be `true`

### 2. Verify Extension Deployment
After deployment, check the VM extensions in Azure Portal:
- **Should have**: `AADLoginForWindows` extension
- **Should NOT have**: `JsonADDomainExtension` extension
- **Should have**: DSC extension with `aadJoin: true`

### 3. Check Session Host Status
In AVD Host Pool:
- Session host should register successfully
- Should show as "Available" status
- Should NOT show domain join errors

## Troubleshooting

### If Still Getting Domain Join Errors:

1. **Verify Template Spec Version**
   ```powershell
   Get-AzTemplateSpec -Name "YourTemplateSpecName" -ResourceGroupName "YourTemplateSpecRG" -Version "1.3"
   ```

2. **Check Runbook Parameters**
   - Ensure `enableAzureADJoin` is set to `$true` in runbook
   - Verify latest Template Spec version is being used

3. **Validate Network Connectivity**
   Azure AD join requires connectivity to:
   - `login.microsoftonline.com`
   - `device.login.microsoftonline.com`
   - `enterpriseregistration.windows.net`

4. **Check Deployment Logs**
   In Azure Portal > Resource Groups > Deployments:
   - Look for template deployment details
   - Check extension deployment logs
   - Verify which extensions were installed

### Common Issues:

1. **Wrong Template Spec Version**: Using old version without fixes
2. **Network Blocking**: Firewall blocking Azure AD endpoints
3. **Missing Parameters**: Template not receiving correct parameters
4. **Extension Conflicts**: Multiple join extensions deployed

## Files Updated
- `AVD-CheckAndRebuildAtLogoff.ps1` - Added explicit domain join parameters
- `sample-templatespec.bicep` - Verified logic for Azure AD join

## Next Steps
1. Update the Template Spec to version 1.4 with this fix
2. Update runbook parameter `TemplateSpecVersion` to "1.4"
3. Test the automation to ensure Azure AD join works correctly
4. Monitor session host registration and health checks

## Validation Commands

```powershell
# Check if VM is Azure AD joined (run on the VM)
Get-AzureADDevice | Where-Object {$_.DisplayName -eq $env:COMPUTERNAME}

# Check AVD session host status
Get-AzWvdSessionHost -HostPoolName "YourHostPool" -ResourceGroupName "YourRG"

# Check VM extensions
Get-AzVMExtension -ResourceGroupName "YourRG" -VMName "YourVM"
```
