# URGENT FIX: DSC Extension Parameter Error Resolution

## Problem Identified
Your deployment is failing with:
```
Code=InvalidExtensionParameter; Message=Extension parameter not supported: domainJoined
```

**Root Cause:** The currently deployed Template Spec version contains the unsupported `domainJoined` parameter in the DSC extension configuration.

## ✅ Code Status (READY)
- ✅ Template Spec code is correct (`sample-templatespec.bicep`)
- ✅ Runbook code is correct (`AVD-CheckAndRebuildAtLogoff.ps1`)
- ✅ Only supported DSC parameters are used: `hostPoolName`, `registrationInfoToken`, `aadJoin`
- ✅ All deprecated parameters removed: `domainJoined`, `mdmId`, `sessionHostConfigurationLastUpdateTime`, etc.

## 🚀 Immediate Action Required

### Step 1: Deploy Corrected Template Spec
```powershell
# Option A: Use the automated script
.\Deploy-FixedTemplateSpec.ps1 -ResourceGroupName "YourTemplateSpecRG" -TemplateSpecName "YourTemplateSpecName" -Location "YourLocation"

# Option B: Manual deployment
New-AzTemplateSpec `
    -ResourceGroupName "YourTemplateSpecRG" `
    -Name "YourTemplateSpecName" `
    -Version "1.8" `
    -Location "YourLocation" `
    -TemplateFile "sample-templatespec.bicep" `
    -DisplayName "AVD Session Host Template v1.8 - Azure AD Join Fixed" `
    -Description "Fixed DSC extension - removed unsupported domainJoined parameter" `
    -Force
```

### Step 2: Update Runbook Configuration
In your Azure Automation Account, update the runbook to use the new version:
```powershell
$TemplateSpecVersion = "1.8"  # Change from your current version
```

### Step 3: Test Deployment
Run your runbook and monitor for:
- ✅ No DSC extension parameter errors
- ✅ Successful Azure AD join
- ✅ Session host registration in AVD

## 🔍 Verification Tools

### Check Current Template Spec Status
```powershell
.\Verify-TemplateSpecConfig.ps1 -ResourceGroupName "YourTemplateSpecRG" -TemplateSpecName "YourTemplateSpecName"
```

### Monitor Session Host Health
```powershell
.\Fix-AVDDomainHealthChecks.ps1 -HostPoolName "YourHostPool" -ResourceGroupName "YourAVDRG"
```

## 📋 What the Fix Accomplishes

### Before (BROKEN - caused the error):
```bicep
properties: {
  hostPoolName: hostPoolName
  registrationInfoToken: registrationInfoToken
  aadJoin: true
  domainJoined: false  // ❌ UNSUPPORTED PARAMETER - CAUSES ERROR
  mdmId: ""           // ❌ DEPRECATED
  // ... other deprecated parameters
}
```

### After (FIXED):
```bicep
properties: {
  hostPoolName: hostPoolName                                    // ✅ SUPPORTED
  registrationInfoToken: registrationInfoToken                 // ✅ SUPPORTED  
  aadJoin: empty(domainToJoin) && enableAzureADJoin ? true : false  // ✅ SUPPORTED
}
```

## 🎯 Expected Results After Fix

1. **Deployment Success:**
   - DSC extension deploys without parameter errors
   - Session hosts successfully created and configured

2. **Azure AD Join:**
   - VMs join Azure AD (not on-premises domain)
   - AADLoginForWindows extension installs successfully

3. **AVD Registration:**
   - Session hosts register with the host pool
   - Status shows as "Available" in AVD admin center

4. **Health Checks Pass:**
   - DomainJoinedCheck: PASS (because host is Azure AD joined)
   - DomainTrustCheck: PASS (because no domain trust required)
   - Other health checks: PASS

## 🚨 If Issues Persist

### Fallback Option: CustomScriptExtension Template
If DSC continues to have issues, use the alternative template:
```powershell
# Deploy the alternative template spec
New-AzTemplateSpec `
    -Name "YourTemplateSpecName-Alternative" `
    -Version "1.0" `
    -TemplateFile "sample-templatespec-alternative.bicep"
```

### Manual Session Host Recovery
Use the diagnostic script for manual intervention:
```powershell
.\Fix-AVDDomainHealthChecks.ps1 -FixMode -HostPoolName "YourHostPool"
```

## 📞 Next Steps Summary

1. **IMMEDIATE:** Deploy Template Spec version 1.8 using `Deploy-FixedTemplateSpec.ps1`
2. **UPDATE:** Change runbook to use version 1.8
3. **TEST:** Run runbook and verify successful deployment
4. **MONITOR:** Check session host health and registration status
5. **CONFIRM:** Verify DomainJoinedCheck and DomainTrustCheck pass

The core issue is simply that you're using an older Template Spec version. Once you deploy the corrected version 1.8 and update your runbook, the DSC extension error should be completely resolved.
