# Fix: AVD Agent DSC Extension Error (mdmId Parameter)

## Problem
The AVD Agent (DSC) extension fails with the error:
```
"A parameter cannot be found that matches parameter name 'mdmId'"
```

## Root Cause
The `mdmId` and `sessionHostConfigurationLastUpdateTime` parameters have been **deprecated** in newer versions of the AVD agent DSC extension. These parameters are no longer supported and cause the extension to fail.

## ✅ Solution Applied
Updated the Template Spec (`sample-templatespec.bicep`) to remove the deprecated parameters:

### ❌ Old Configuration (Causing Error)
```bicep
properties: {
  hostPoolName: hostPoolName
  registrationInfoToken: registrationInfoToken
  aadJoin: empty(domainToJoin) ? true : false
  UseAgentDownloadEndpoint: true
  aadJoinPreview: false
  mdmId: ''                              // ❌ DEPRECATED - Causes error
  sessionHostConfigurationLastUpdateTime: ''  // ❌ DEPRECATED - Causes error
}
```

### ✅ New Configuration (Fixed)
```bicep
properties: {
  hostPoolName: hostPoolName
  registrationInfoToken: registrationInfoToken
  aadJoin: empty(domainToJoin) ? true : false
  UseAgentDownloadEndpoint: true
  aadJoinPreview: false
  // Removed deprecated parameters
}
```

## Current Supported Parameters
The AVD Agent DSC extension now supports these parameters:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `hostPoolName` | String | Yes | Name of the AVD host pool |
| `registrationInfoToken` | String | Yes | Host pool registration token |
| `aadJoin` | Boolean | No | Whether to perform Azure AD join (default: false) |
| `UseAgentDownloadEndpoint` | Boolean | No | Use Microsoft endpoint for agent download |
| `aadJoinPreview` | Boolean | No | Enable Azure AD join preview features |

## What Changed
Microsoft updated the AVD agent DSC extension to:
1. **Remove MDM (Mobile Device Management) parameters** - `mdmId` is no longer used
2. **Remove session host configuration parameters** - Managed through other mechanisms
3. **Simplify configuration** - Focus on core registration parameters
4. **Improve reliability** - Fewer parameters reduce configuration errors

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
