# Fix: AVD Health Check Errors (DomainJoinedCheck/DomainTrustCheck)

## Problem
Azure Virtual Desktop health checks are failing with:
- `DomainJoinedCheck` - FAILED
- `DomainTrustCheck` - FAILED

These errors occur when VMs are not domain joined but the AVD agent expects them to be.

## Root Cause
**Logic error in Template Spec**: The `aadJoin` parameter in the DSC extension was incorrectly configured:

### ❌ Incorrect Logic (Causing Health Check Failures)
```bicep
aadJoin: empty(domainToJoin) ? true : false
```

This logic only considers whether `domainToJoin` is empty, but **ignores** the `enableAzureADJoin` parameter.

**Result**: Even when `enableAzureADJoin = false`, the DSC extension still receives `aadJoin: true`, causing the AVD agent to expect Azure AD join when none occurred.

### ✅ Correct Logic (Fixed)
```bicep
aadJoin: empty(domainToJoin) && enableAzureADJoin ? true : false
```

This logic considers **both conditions**:
- `domainToJoin` must be empty (no domain join)
- `enableAzureADJoin` must be true (Azure AD join enabled)

## Logic Table
| domainToJoin | enableAzureADJoin | Result | Behavior |
|--------------|-------------------|--------|----------|
| Empty | true | `aadJoin: true` | ✅ Azure AD join expected and performed |
| Empty | false | `aadJoin: false` | ✅ No join expected, standalone VM |
| Not Empty | true | `aadJoin: false` | ✅ Domain join expected and performed |
| Not Empty | false | `aadJoin: false` | ✅ Domain join expected and performed |

## Impact of the Fix

### Before Fix (Broken Scenarios)
- **Scenario**: `enableAzureADJoin = false` (network issues)
- **DSC Extension**: `aadJoin: true` (incorrect)
- **AVD Agent**: Expects Azure AD join but finds none
- **Health Check**: ❌ FAILS with DomainJoinedCheck/DomainTrustCheck errors

### After Fix (Working Scenarios)
- **Scenario**: `enableAzureADJoin = false` (network issues)
- **DSC Extension**: `aadJoin: false` (correct)
- **AVD Agent**: Expects standalone VM (no join)
- **Health Check**: ✅ PASSES, VM shows as Available

## What This Means for Your Deployment

### Current Issue
Your runbook sets `enableAzureADJoin = false` (to avoid network connectivity issues), but the Template Spec was still telling the AVD agent to expect Azure AD join, causing health check failures.

### After Fix
- VMs will deploy as **standalone/workgroup** VMs (no domain join)
- AVD agent will **not expect** any domain join
- Health checks will **pass** 
- Session hosts will show as **Available**
- Users can still connect (AVD works without domain join for many scenarios)

## Deployment Steps

### 1. Deploy Updated Template Spec
```powershell
# Deploy Template Spec version 1.3 with the logic fix
New-AzTemplateSpec `
    -ResourceGroupName "rg-templates" `
    -Name "AVD-VM-Template" `
    -Version "1.3" `
    -Location "East US" `
    -TemplateFile "sample-templatespec.bicep" `
    -Description "Fixed aadJoin logic to respect enableAzureADJoin parameter"
```

### 2. Update Runbook Parameter
```powershell
$TemplateSpecVersion = "1.3"  # Use the fixed version
```

### 3. Test Deployment
Run your automation - VMs should now:
- ✅ Deploy successfully
- ✅ Pass AVD health checks
- ✅ Show as "Available" in host pool
- ✅ Allow user connections

## Alternative Scenarios

### Option 1: Standalone VMs (Recommended for your case)
- `enableAzureADJoin = false`
- `domainToJoin = ""` (empty)
- **Result**: Standalone VMs, no domain join, AVD works

### Option 2: Azure AD Join (When network is fixed)
- `enableAzureADJoin = true`
- `domainToJoin = ""` (empty)
- **Result**: Azure AD joined VMs, full integration

### Option 3: Domain Join (Traditional)
- `enableAzureADJoin = false` (doesn't matter)
- `domainToJoin = "yourdomain.com"`
- **Result**: Domain joined VMs, traditional setup

## Verification
After deployment, check:

1. **Session Host Status**:
   ```powershell
   Get-AzWvdSessionHost -HostPoolName "your-host-pool" -ResourceGroupName "rg-avd"
   ```

2. **VM Join Status**:
   - Remote to VM and run: `dsregcmd /status`
   - Should show: `DomainJoined: NO`, `AzureAdJoined: NO` (for standalone)

3. **AVD Agent Health**:
   - Check Azure Portal → AVD → Host pools → Session hosts
   - Status should be "Available"

## Related Files
- `sample-templatespec.bicep` - Updated with fixed aadJoin logic
- `AVD-CheckAndRebuildAtLogoff.ps1` - Runbook that passes enableAzureADJoin parameter
- `RUNBOOK_CONFIGURATION.md` - Parameter configuration guide

This fix resolves the mismatch between the Template Spec configuration and the actual VM deployment state, ensuring AVD health checks pass correctly.
