# URGENT: Deploy Corrected Template Spec to Fix DSC Extension Error

## Problem
The deployment is failing with this error:
```
Code=InvalidExtensionParameter; Message=Extension parameter not supported: domainJoined
```

This indicates the Template Spec currently deployed still contains the invalid `domainJoined` parameter.

## Solution
Deploy the corrected Template Spec as a new version that only uses supported DSC parameters.

## Step 1: Deploy New Template Spec Version

Run this command to deploy the corrected Template Spec as version 1.8:

```powershell
# Navigate to the directory containing your template spec
cd "C:\path\to\your\template\spec\directory"

# Deploy as new version (replace with your actual resource group and subscription)
New-AzTemplateSpec `
    -ResourceGroupName "YourTemplateSpecResourceGroup" `
    -Name "YourTemplateSpecName" `
    -Version "1.8" `
    -Location "YourLocation" `
    -TemplateFile "sample-templatespec.bicep" `
    -DisplayName "AVD Session Host Template v1.8 - Azure AD Join Fixed" `
    -Description "Fixed DSC extension to only use supported parameters: hostPoolName, registrationInfoToken, aadJoin" `
    -Force
```

## Step 2: Update Runbook to Use New Version

Update your automation runbook to reference version 1.8:

```powershell
# In your runbook parameters or variables, change:
$TemplateSpecVersion = "1.8"  # Was probably "1.7" or lower
```

## Step 3: Test Deployment

1. Run the runbook with the new Template Spec version
2. Monitor the deployment for any errors
3. Verify the DSC extension deploys successfully without the `domainJoined` parameter error

## What Was Fixed

The corrected Template Spec (sample-templatespec.bicep) now only passes these supported parameters to the DSC extension:

```bicep
properties: {
  hostPoolName: hostPoolName
  registrationInfoToken: registrationInfoToken
  aadJoin: empty(domainToJoin) && enableAzureADJoin ? true : false
}
```

**Removed unsupported parameters:**
- ❌ `domainJoined` (not supported in DSC extension)
- ❌ `mdmId` (deprecated)
- ❌ `sessionHostConfigurationLastUpdateTime` (deprecated)
- ❌ `aadJoinPreview` (deprecated)
- ❌ `UseAgentDownloadEndpoint` (deprecated)

## Verification Commands

After deployment, verify the Template Spec version:

```powershell
# Check template spec versions
Get-AzTemplateSpec -Name "YourTemplateSpecName" -ResourceGroupName "YourTemplateSpecResourceGroup"

# View the specific version details
Get-AzTemplateSpec -Name "YourTemplateSpecName" -ResourceGroupName "YourTemplateSpecResourceGroup" -Version "1.8"
```

## If Still Getting Errors

If you still encounter DSC extension errors after deploying version 1.8:

1. **Use the alternative Template Spec:** Deploy `sample-templatespec-alternative.bicep` which uses CustomScriptExtension instead of DSC
2. **Manual verification:** Use the diagnostic script `Fix-AVDDomainHealthChecks.ps1` to check session host status
3. **Check current deployment:** Verify the runbook is actually using the new version 1.8

## Expected Result

After deploying the corrected Template Spec v1.8:
- ✅ DSC extension should deploy without parameter errors
- ✅ Session hosts should Azure AD join successfully
- ✅ AVD agent should register with the host pool
- ✅ DomainJoinedCheck and DomainTrustCheck health check failures should be resolved
