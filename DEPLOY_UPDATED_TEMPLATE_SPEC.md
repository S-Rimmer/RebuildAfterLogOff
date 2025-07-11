# Quick Fix: Deploy Updated Template Spec

## Problem
Your runbook is still using an old version of the Template Spec that contains deprecated DSC extension parameters.

## Solution: Deploy Updated Template Spec

### Step 1: Deploy the Fixed Template Spec

**Option A: Using Azure PowerShell**
```powershell
# Deploy the updated Template Spec with version 1.3
New-AzTemplateSpec `
    -ResourceGroupName "rg-templates" `
    -Name "AVD-VM-Template" `
    -Version "1.3" `
    -Location "East US" `
    -TemplateFile "sample-templatespec.bicep" `
    -Description "Fixed aadJoin logic and removed all deprecated parameters"
```

**Option B: Using Azure CLI**
```bash
# Deploy the updated Template Spec with version 1.3
az ts create \
    --resource-group "rg-templates" \
    --name "AVD-VM-Template" \
    --version "1.3" \
    --location "East US" \
    --template-file "sample-templatespec.bicep" \
    --description "Fixed aadJoin logic and removed deprecated parameters"
```

### Step 2: Update Your Runbook Parameter

**In Azure Portal:**
1. Navigate to your Automation Account
2. Go to **Runbooks** → Select your runbook
3. Click **Edit** → **Parameters**
4. Update `TemplateSpecVersion` from `"1.0"` to `"1.3"`
5. **Save** and **Publish**

**In PowerShell (if starting runbook manually):**
```powershell
# Update the Template Spec version parameter
$TemplateSpecVersion = "1.3"  # ← Change this from "1.0"
```

### Step 3: Test the Fix

Run your automation runbook again. The DSC extension error should now be resolved.

## What This Fixes

The updated Template Spec now fixes **both issues**:

### 1. Removed All Deprecated Parameters
**DSC Extension - Only Essential Parameters:**
```bicep
settings: {
  properties: {
    hostPoolName: hostPoolName
    registrationInfoToken: registrationInfoToken
    aadJoin: empty(domainToJoin) && enableAzureADJoin ? true : false  // ✅ FIXED LOGIC
    // ✅ All deprecated parameters removed:
    // ❌ UseAgentDownloadEndpoint (removed)
    // ❌ aadJoinPreview (removed)
    // ❌ mdmId (removed)
    // ❌ sessionHostConfigurationLastUpdateTime (removed)
  }
}
```

### 2. Fixed Azure AD Join Logic  
**Before (Broken):**
```bicep
aadJoin: empty(domainToJoin) ? true : false  // ❌ Ignores enableAzureADJoin
```

**After (Fixed):**
```bicep
aadJoin: empty(domainToJoin) && enableAzureADJoin ? true : false  // ✅ Considers both parameters
```

**Impact**: 
- When `enableAzureADJoin = false`, VMs deploy as standalone (no domain join expected)
- AVD health checks pass (no more DomainJoinedCheck/DomainTrustCheck errors)
- Session hosts show as "Available"

**AADLoginForWindows Extension - No Configuration:**
```bicep
properties: {
  publisher: 'Microsoft.Azure.ActiveDirectory'
  type: 'AADLoginForWindows'
  typeHandlerVersion: '1.0'
  autoUpgradeMinorVersion: true
  // ✅ No settings block required
}
```

## Verification

After deployment, check:

1. **Template Spec exists:**
   ```powershell
   Get-AzTemplateSpec -ResourceGroupName "rg-templates" -Name "AVD-VM-Template"
   ```

2. **Version 1.3 is available:**
   ```powershell
   Get-AzTemplateSpec -ResourceGroupName "rg-templates" -Name "AVD-VM-Template" -Version "1.3"
   ```

3. **Run your automation** - DSC extension should work without errors

## Troubleshooting

### Template Spec Deployment Fails
- Ensure you have **Template Spec Contributor** role on the resource group
- Check that the Bicep file is valid using: `az bicep build --file sample-templatespec.bicep`

### Runbook Still Uses Old Version
- Verify the `TemplateSpecVersion` parameter is updated to `"1.3"`
- Check that you saved and published the runbook after making changes

### Still Getting DSC Errors
- Verify the Template Spec was deployed successfully
- Check that your Bicep file contains the latest fixes (no deprecated parameters)
- Review the ARM deployment logs for detailed error information

## Next Steps

1. **Deploy the updated Template Spec** using one of the methods above
2. **Update your runbook parameter** to use version "1.3"  
3. **Test your automation** - it should now complete successfully
4. **Monitor the session hosts** to ensure they register properly in AVD

This should resolve the `aadJoinPreview` parameter error and allow your automation to complete successfully!
