# DEPLOY FRESH AZURE AD TEMPLATE - COMPLETE SETUP GUIDE

## Issue Resolved
The template deployment error has been fixed:
```
❌ OLD ERROR: 'The following parameters were supplied, but do not correspond to any parameters defined in the template: 'domainToJoin, domainUsername, domainPassword, ouPath''
✅ FIXED: Runbook updated to only pass parameters that exist in the fresh template
```

## Quick Deployment Steps

### Step 1: Deploy Fresh Template Spec (Version 2.0)
```powershell
# Navigate to your workspace directory
cd "path\to\RebuildAfterLogOff"

# Deploy the fresh template spec
.\Deploy-FreshAADTemplateSpec.ps1 `
    -ResourceGroupName "YourTemplateSpecRG" `
    -TemplateSpecName "YourTemplateSpecName" `
    -Location "YourLocation" `
    -Version "2.0"
```

### Step 2: Update VNet Resource Group (Required)
Edit `fresh-aad-templatespec.bicep` line 95:
```bicep
# Change this line:
scope: resourceGroup('EST2_SharedResources')

# To your actual VNet resource group:
scope: resourceGroup('YourActualVNetResourceGroup')
```

### Step 3: Update Runbook Configuration
In your Azure Automation Account, update the runbook to use the new template version:
```powershell
$TemplateSpecVersion = "2.0"  # Change from your current version
```

### Step 4: Test Deployment
Run your runbook and verify successful deployment.

## What Was Fixed in the Runbook

### Before (BROKEN):
```powershell
$templateParams = @{
    # ... other parameters ...
    enableAzureADJoin = $enableAzureADJoin
    # Domain join parameters - explicitly set to empty for Azure AD join
    domainToJoin = ""        # ❌ NOT IN FRESH TEMPLATE
    ouPath = ""             # ❌ NOT IN FRESH TEMPLATE  
    domainUsername = ""     # ❌ NOT IN FRESH TEMPLATE
    domainPassword = ""     # ❌ NOT IN FRESH TEMPLATE
}
```

### After (FIXED):
```powershell
$templateParams = @{
    # ... other parameters ...
    enableAzureADJoin = $enableAzureADJoin
    # No domain parameters - fresh template is Azure AD only
}
```

## Fresh Template Parameters (Complete List)

The fresh template (`fresh-aad-templatespec.bicep`) accepts these parameters:

**✅ Required Parameters:**
- `vmName` - Name of the virtual machine
- `adminUsername` - Administrator username
- `adminPassword` - Administrator password
- `hostPoolName` - AVD host pool name
- `vnetName` - Virtual network name
- `subnetName` - Subnet name
- `registrationInfoToken` - AVD registration token

**✅ Image Parameters:**
- `useGalleryImage` - true/false for gallery vs marketplace
- `imageId` - Gallery image ID (when useGalleryImage = true)
- `imagePublisher` - Marketplace publisher (when useGalleryImage = false)
- `imageOffer` - Marketplace offer (when useGalleryImage = false)
- `imageSku` - Marketplace SKU (when useGalleryImage = false)
- `imageVersion` - Marketplace version (when useGalleryImage = false)

**✅ Optional Parameters:**
- `vmSize` - VM size (default: Standard_D2s_v3)
- `resourceGroupName` - Resource group name
- `location` - Location (default: resourceGroup().location)
- `securityType` - Standard or TrustedLaunch (default: TrustedLaunch)
- `enableSecureBoot` - true/false (default: true)
- `enableVtpm` - true/false (default: true)
- `enableAzureADJoin` - true/false (default: true)

**❌ NOT INCLUDED (Azure AD Only):**
- `domainToJoin` - Removed (Azure AD only)
- `domainUsername` - Removed (Azure AD only)
- `domainPassword` - Removed (Azure AD only)
- `ouPath` - Removed (Azure AD only)

## Expected Deployment Process

### 1. VM Creation
- ✅ VM created with Trusted Launch security
- ✅ System-assigned managed identity
- ✅ Premium SSD storage with delete option

### 2. Azure AD Join
- ✅ AADLoginForWindows extension installs
- ✅ VM joins Azure AD automatically
- ✅ No domain join attempts

### 3. Registry Pre-Configuration
- ✅ Sets `AADJoined = 1` in registry
- ✅ Sets `DomainJoined = 0` in registry
- ✅ Prepares environment for AVD agent

### 4. AVD Agent Installation
- ✅ DSC extension with only supported parameters
- ✅ Latest AVD agent module (Configuration_09-08-2022.zip)
- ✅ Registers with host pool successfully

### 5. Health Check Configuration
- ✅ Disables domain health checks
- ✅ Enables Azure AD health checks
- ✅ Restarts AVD services

## Verification Commands

### Check Template Spec Deployment
```powershell
Get-AzTemplateSpec -Name "YourTemplateSpecName" -ResourceGroupName "YourTemplateSpecRG" -Version "2.0"
```

### Test Template Parameters
```powershell
.\Test-FreshAADTemplate.ps1 `
    -ResourceGroupName "YourTemplateSpecRG" `
    -TemplateSpecName "YourTemplateSpecName" `
    -HostPoolName "YourHostPool" `
    -AVDResourceGroup "YourAVDRG" `
    -Version "2.0"
```

### Monitor Session Host Status
```powershell
Get-AzWvdSessionHost -HostPoolName "YourHostPool" -ResourceGroupName "YourAVDRG"
```

## Expected Results After Fix

### ✅ Deployment Success
- No template parameter errors
- VM deploys successfully
- All extensions install without errors

### ✅ Azure AD Join
- VM appears in Azure AD devices
- AADLoginForWindows extension shows as successful
- No domain join attempts or errors

### ✅ AVD Registration
- Session host appears in host pool
- Status shows as "Available"
- Health checks all pass

### ✅ Health Check Results
- **DomainJoinedCheck:** PASS (disabled for Azure AD)
- **DomainTrustCheck:** PASS (disabled for Azure AD)
- **AADJoinedCheck:** PASS
- **All other checks:** PASS

## Troubleshooting

### If Still Getting Parameter Errors
1. Verify you're using the updated runbook
2. Check Template Spec version is 2.0
3. Ensure no old parameters are being passed

### If Health Checks Fail
1. Check VM extensions status in Azure Portal
2. Run diagnostic script: `.\Fix-AVDDomainHealthChecks.ps1`
3. Verify registry settings manually

### If AVD Agent Fails
1. Check DSC extension logs
2. Verify registration token is valid
3. Check network connectivity to AVD endpoints

## Summary

The fresh template and updated runbook combination provides:
- ✅ **Zero domain join logic** - Pure Azure AD join
- ✅ **Automated health check configuration** - No manual registry edits
- ✅ **Modern security features** - Trusted Launch, managed identity
- ✅ **Optimized extension sequence** - Proper dependencies and timing
- ✅ **Complete automation** - No post-deployment manual steps required

This should completely resolve your domain health check issues while maintaining proper Azure AD join functionality.
