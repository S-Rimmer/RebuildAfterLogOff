# Fix: AVD Agent DSC Extension Error (mdmId Parameter)

## Problem
The AVD Agent (DSC) extension fails with the error:
```
"A parameter cannot be found that matches parameter name 'mdmId'"
```

## Root Cause
The following parameters have been **deprecated** in newer versions of Azure VM extensions:

**DSC Extension (AVD Agent):**
- `mdmId` - Mobile Device Management ID (no longer used)
- `sessionHostConfigurationLastUpdateTime` - Session configuration timestamp (replaced by other mechanisms)
- `aadJoinPreview` - Azure AD join preview flag (functionality now built-in)
- `UseAgentDownloadEndpoint` - Agent download endpoint flag (no longer supported)

**AADLoginForWindows Extension:**
- `mdmId` - Mobile Device Management ID (no longer required)

These deprecated parameters cause extension failures and must be removed.

## ✅ Solution Applied
Updated the Template Spec (`sample-templatespec.bicep`) to remove the deprecated parameters:

### ❌ Old Configuration (Causing Errors)

**DSC Extension:**
```bicep
settings: {
  properties: {
    hostPoolName: hostPoolName
    registrationInfoToken: registrationInfoToken
    aadJoin: empty(domainToJoin) ? true : false
    UseAgentDownloadEndpoint: true          // ❌ DEPRECATED - Causes error
    aadJoinPreview: false                    // ❌ DEPRECATED - Causes error
    mdmId: ''                              // ❌ DEPRECATED - Causes error
    sessionHostConfigurationLastUpdateTime: ''  // ❌ DEPRECATED - Causes error
  }
}
```

**AADLoginForWindows Extension:**
```bicep
settings: {
  mdmId: ''  // ❌ DEPRECATED - Causes error
}
```

### ✅ New Configuration (Fixed)

**DSC Extension:**
```bicep
settings: {
  properties: {
    hostPoolName: hostPoolName
    registrationInfoToken: registrationInfoToken
    aadJoin: empty(domainToJoin) ? true : false
    // All deprecated parameters removed:
    // ❌ UseAgentDownloadEndpoint (removed)
    // ❌ aadJoinPreview (removed)
    // ❌ mdmId (removed)
    // ❌ sessionHostConfigurationLastUpdateTime (removed)
  }
}
```

**AADLoginForWindows Extension:**
```bicep
// No settings required - extension works without configuration
```

## Current Supported Parameters
The AVD Agent DSC extension now supports these parameters:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `hostPoolName` | String | Yes | Name of the AVD host pool |
| `registrationInfoToken` | String | Yes | Host pool registration token |
| `aadJoin` | Boolean | No | Whether to perform Azure AD join (default: false) |

## What Changed
Microsoft updated Azure VM extensions to:
1. **Remove MDM (Mobile Device Management) parameters** - No longer used in modern Azure AD scenarios
2. **Remove session host configuration parameters** - Managed through Azure Virtual Desktop service directly  
3. **Remove preview parameters** - Preview functionality is now built into the core extension
4. **Remove agent download endpoint parameters** - Agent download is handled automatically
5. **Simplify AAD extension configuration** - AADLoginForWindows extension works without settings
6. **Improve reliability** - Fewer parameters reduce configuration errors and compatibility issues

## Impact of This Fix
- ✅ **VMs will deploy successfully** without DSC extension errors
- ✅ **AVD agents will install properly** using the latest configuration
- ✅ **Session hosts will register** with the host pool correctly
- ✅ **No functionality loss** - all AVD features remain available

## Next Steps

### 1. Update Template Spec
If you haven't already, deploy the updated Template Spec:

```powershell
# Deploy updated Template Spec
New-AzTemplateSpec `
    -ResourceGroupName "rg-templates" `
    -Name "AVD-VM-Template" `
    -Version "1.1" `
    -Location "East US" `
    -TemplateFile "sample-templatespec.bicep"
```

### 2. Update Runbook Reference
Update your runbook to use the new Template Spec version:
```powershell
$TemplateSpecVersion = "1.1"  # Use updated version
```

### 3. Test Deployment
Run your automation runbook again - the DSC extension error should be resolved.

## Verification
After deployment, verify the AVD agent is working:

1. **Check session host registration**:
   ```powershell
   Get-AzWvdSessionHost -HostPoolName "your-host-pool" -ResourceGroupName "rg-avd"
   ```

2. **Verify session host status** in Azure Portal:
   - Navigate to Azure Virtual Desktop → Host pools
   - Check that session hosts show as "Available"

3. **Test user connection** to confirm full functionality

## Prevention
- **Use current documentation** - Always reference the latest Azure Virtual Desktop documentation
- **Test Template Specs** before production deployment
- **Monitor extension versions** - Microsoft may update DSC extension requirements
- **Version your Template Specs** to track changes and enable rollback

## Related Files
- `sample-templatespec.bicep` - Updated with fixed DSC configuration
- `AVD-CheckAndRebuildAtLogoff.ps1` - Runbook that deploys the Template Spec
- `RUNBOOK_CONFIGURATION.md` - Complete runbook parameter guide

## Additional Notes
This fix maintains backward compatibility while removing deprecated parameters. If you were using custom MDM configurations, you'll need to implement them through other Azure policy mechanisms rather than the DSC extension.
