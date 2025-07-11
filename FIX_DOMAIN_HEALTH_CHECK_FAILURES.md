# Fix: Domain Health Check Failures on Azure AD Joined VMs

## 🔍 Problem Analysis
Your VM is now successfully Azure AD joined, but AVD health checks are still failing on:
- `DomainJoinedCheck` 
- `DomainTrustCheck`

This happens because these health checks are being performed even though the VM should be in Azure AD-only mode.

## 🔧 Root Causes & Solutions

### 1. Host Pool Configuration Issue
The most common cause is that your **Host Pool is not configured for Azure AD-only environments**.

#### Check Host Pool Configuration:
```powershell
# Check your current host pool configuration
Get-AzWvdHostPool -ResourceGroupName "YourRG" -Name "YourHostPoolName" | Select-Object Name, DomainJoined, PreferredAppGroupType, LoadBalancerType
```

**✅ Your Host Pool Configuration Looks Correct:**
```
Name             DomainJoined PreferredAppGroupType LoadBalancerType
----             ------------ --------------------- ----------------
vdpool-RBAL-use2              Desktop               Persistent
```

The `DomainJoined` field being empty indicates your Host Pool supports both Azure AD and domain-joined VMs, which is correct.

#### Fix Host Pool for Azure AD-Only:
If your Host Pool shows `DomainJoined: True`, you need to update it:

```powershell
# Update Host Pool to support Azure AD-only
Update-AzWvdHostPool -ResourceGroupName "YourRG" -Name "YourHostPoolName" -FriendlyName "Azure AD Only Host Pool"
```

### 2. AVD Agent Configuration Updates

The DSC extension needs to be told explicitly that domain checks should be skipped. The current Template Spec has been updated to ensure `aadJoin: true` when Azure AD join is enabled.

### 3. Host Pool Type Verification

Verify your Host Pool was created with the correct type:

```powershell
# Check Host Pool properties
$hostPool = Get-AzWvdHostPool -ResourceGroupName "YourRG" -Name "YourHostPoolName"
Write-Output "Host Pool Type: $($hostPool.HostPoolType)"
Write-Output "Load Balancer Type: $($hostPool.LoadBalancerType)"
Write-Output "Preferred App Group Type: $($hostPool.PreferredAppGroupType)"
```

## 🛠️ Complete Fix Steps

### Step 1: Update Template Spec
Deploy the updated Template Spec (already fixed):
```powershell
New-AzTemplateSpec -ResourceGroupName "YourTemplateSpecRG" -Name "YourTemplateSpecName" -Version "1.5" -Location "YourLocation" -TemplateFile "c:\Users\srimmer\Downloads\sample-templatespec.bicep"
```

### Step 2: Update Runbook Parameter
Update `TemplateSpecVersion` parameter to "1.5"

### Step 3: Check Host Pool Configuration
```powershell
# Verify Host Pool supports Azure AD join
$hostPool = Get-AzWvdHostPool -ResourceGroupName "YourAVDRG" -Name "YourHostPoolName"

# Look for these settings - they should support Azure AD join
Write-Output "Host Pool Details:"
Write-Output "- Type: $($hostPool.HostPoolType)"
Write-Output "- Load Balancer: $($hostPool.LoadBalancerType)" 
Write-Output "- Preferred App Group: $($hostPool.PreferredAppGroupType)"
```

### Step 4: Verify VM Extensions After Deployment
After running your automation, check that the VM has the correct extensions:

```powershell
# Check VM extensions
Get-AzVMExtension -ResourceGroupName "YourVMRG" -VMName "YourVMName" | Select-Object Name, Publisher, TypeHandlerVersion, ProvisioningState

# Should show:
# - AADLoginForWindows (Microsoft.Azure.ActiveDirectory)
# - DSC (Microsoft.PowerShell) with ProvisioningState: Succeeded
# - Should NOT show JsonADDomainExtension
```

### Step 5: Check DSC Extension Configuration
Verify the DSC extension has the correct settings:

```powershell
# Get DSC extension details
$dscExt = Get-AzVMExtension -ResourceGroupName "YourVMRG" -VMName "YourVMName" -Name "AVDAgent"
$dscExt.Settings | ConvertFrom-Json | Select-Object -ExpandProperty properties
```

Should show: `aadJoin: True`

## 🔬 Troubleshooting Health Check Failures

Since your Host Pool configuration is correct, the domain health check failures are likely due to the AVD agent still performing these checks. Here are the solutions:

### Option 1: Wait for Health Check Timeout (Recommended First Step)
Domain health checks will eventually timeout and stop being performed. Wait 30-60 minutes after VM deployment and check session host status again.

### Option 2: Update to Latest AVD Configuration Module
The current DSC configuration is from 2021. Try using a newer configuration:

Update your Template Spec DSC extension to use a more recent configuration:
```bicep
settings: {
  modulesUrl: 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_09-08-2022.zip'
  configurationFunction: 'Configuration.ps1\\AddSessionHost'
  properties: {
    hostPoolName: hostPoolName
    registrationInfoToken: registrationInfoToken
    aadJoin: true
  }
}
```

### Option 3: Restart AVD Agent Service
On the VM, restart the AVD services:

```powershell
# Run on the VM
Restart-Service -Name "RDAgentBootLoader" -Force
Restart-Service -Name "Remote Desktop Agent Loader" -Force
```

### Option 4: Check Current Session Host Status
Run this command to see the exact health check failures:

```powershell
# Check detailed session host health
Get-AzWvdSessionHost -HostPoolName "vdpool-RBAL-use2" -ResourceGroupName "YourRG" -Name "YourSessionHost" | Select-Object Name, Status, LastHeartBeat, AllowNewSession, SessionHostHealthCheckResult
```

### Option 5: Force Health Check Refresh
Sometimes manually triggering a health check refresh helps:

```powershell
# Update session host to trigger health check refresh
Update-AzWvdSessionHost -HostPoolName "vdpool-RBAL-use2" -ResourceGroupName "YourRG" -Name "YourSessionHost" -AllowNewSession:$true
```

## ✅ Expected Results After Fix

1. **VM Extensions**: Only `AADLoginForWindows` and `DSC` extensions
2. **Session Host Status**: "Available" without health check errors
3. **Health Checks**: No DomainJoinedCheck or DomainTrustCheck failures
4. **VM Join Status**: Azure AD joined, not domain joined

## 🔍 Verification Commands

```powershell
# Check session host health
Get-AzWvdSessionHost -HostPoolName "YourHostPool" -ResourceGroupName "YourRG" -Name "YourSessionHost" | Select-Object Name, Status, LastHeartBeat, AllowNewSession

# Check for any health check errors
Get-AzWvdSessionHost -HostPoolName "YourHostPool" -ResourceGroupName "YourRG" -Name "YourSessionHost" | Select-Object -ExpandProperty SessionHostHealthCheckResult
```

## 🚨 Important Notes

1. **Host Pool Type**: Personal host pools work better with Azure AD join
2. **App Group**: Ensure app groups are configured for the new host pool
3. **User Assignment**: May need to reassign users if recreating host pool
4. **Conditional Access**: Ensure Azure AD Conditional Access policies allow AVD access

The key is ensuring both the VM configuration (Template Spec) and Host Pool configuration are aligned for Azure AD-only environments.
