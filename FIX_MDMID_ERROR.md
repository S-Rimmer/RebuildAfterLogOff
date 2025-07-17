# URGENT FIX: Azure AD Join Extension mdmId Error

## Issue Identified
Your deployment is failing with:
```
Error: 'mdmId' setting was not found. Please input the 'mdmId' setting. This setting is case sensitive
```

**Root Cause:** Microsoft recently updated the AADLoginForWindows extension to require the `mdmId` setting, even for basic Azure AD join without MDM enrollment.

## ✅ Fix Applied

### 1. Updated Fresh Template (`fresh-aad-templatespec.bicep`)
**Added mdmId parameter:**
```bicep
@description('MDM enrollment ID for Azure AD join (empty for basic Azure AD join)')
param mdmId string = ''
```

**Updated AAD Join extension settings:**
```bicep
settings: {
  mdmId: mdmId // Required setting - empty string for basic Azure AD join without MDM enrollment
}
```

### 2. Updated Runbook (`AVD-CheckAndRebuildAtLogoff.ps1`)
**Added mdmId to template parameters:**
```powershell
mdmId = "" # Empty for basic Azure AD join without MDM enrollment
```

## 🚀 Deployment Steps

### Step 1: Deploy Updated Template Spec (Version 2.1)
```powershell
# Deploy the fixed template spec
.\Deploy-FreshAADTemplateSpec.ps1 `
    -ResourceGroupName "YourTemplateSpecRG" `
    -TemplateSpecName "YourTemplateSpecName" `
    -Location "YourLocation" `
    -Version "2.1"
```

### Step 2: Update Runbook Configuration
Update your runbook to use the new template version:
```powershell
$TemplateSpecVersion = "2.1"  # Change from "2.0"
```

### Step 3: Test Deployment
Run your runbook - the mdmId error should be resolved.

## 📋 What mdmId Means

The `mdmId` parameter controls Mobile Device Management (MDM) enrollment:

- **Empty string (`""`)**: Basic Azure AD join without MDM enrollment (recommended for AVD)
- **GUID value**: Enrolls device in specified MDM solution (like Intune)

For AVD session hosts, we use an empty string because:
- ✅ AVD session hosts don't typically need MDM enrollment
- ✅ Simplifies deployment and management
- ✅ Avoids potential conflicts with AVD-specific configurations
- ✅ Maintains focus on Azure AD authentication only

## 🔍 Verification

After deploying the updated template, verify:

### Check Extension Status
```powershell
# Check AAD Login extension status
Get-AzVMExtension -ResourceGroupName "YourVMRG" -VMName "YourVMName" -Name "AADLoginForWindows"
```

### Check Session Host Registration
```powershell
# Verify session host appears in host pool
Get-AzWvdSessionHost -HostPoolName "YourHostPool" -ResourceGroupName "YourAVDRG"
```

### Expected Results
- ✅ AADLoginForWindows extension: Succeeded
- ✅ VM joined to Azure AD
- ✅ No mdmId errors in deployment logs
- ✅ Session host registered and available

## 🛠️ Alternative MDM Configurations (Optional)

If you need MDM enrollment in the future, you can use these mdmId values:

### Microsoft Intune
```powershell
mdmId = "0000000a-0000-0000-c000-000000000000"  # Microsoft Intune
```

### Custom MDM Solution
```powershell
mdmId = "your-custom-mdm-guid"  # Your organization's MDM solution
```

### No MDM (Current Configuration)
```powershell
mdmId = ""  # Basic Azure AD join only (current setup)
```

## 📊 Template Parameters Updated

The fresh template now includes these parameters:

**✅ New Parameter:**
- `mdmId` - MDM enrollment ID (default: empty string)

**✅ All Parameters:**
- `vmName`, `vmSize`, `adminUsername`, `adminPassword`
- `hostPoolName`, `resourceGroupName`, `location`
- `vnetName`, `subnetName`, `registrationInfoToken`
- `useGalleryImage`, `imageId`, `imagePublisher`, `imageOffer`, `imageSku`, `imageVersion`
- `securityType`, `enableSecureBoot`, `enableVtpm`
- `enableAzureADJoin`, `mdmId`

## 🚨 Important Notes

1. **This is a breaking change** from Microsoft - the AADLoginForWindows extension now requires mdmId
2. **Empty string is valid** - you don't need an actual MDM solution
3. **Case sensitive** - parameter must be exactly `mdmId` (not `mdmID` or `MdmId`)
4. **Required for all deployments** - even basic Azure AD join needs this setting

## 📈 Expected Deployment Flow

After this fix:
1. ✅ VM creation succeeds
2. ✅ AADLoginForWindows extension installs successfully (with mdmId)
3. ✅ VM joins Azure AD without MDM enrollment
4. ✅ Pre-configuration script sets registry values
5. ✅ AVD agent installs and registers
6. ✅ Post-configuration script optimizes health checks
7. ✅ Session host appears as "Available"

The mdmId fix ensures compatibility with Microsoft's latest AADLoginForWindows extension requirements while maintaining your Azure AD-only AVD environment.
