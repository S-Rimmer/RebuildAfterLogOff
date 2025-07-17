# Fresh Azure AD-Only AVD Template Spec Guide

## Overview
This guide covers deploying and using the fresh `fresh-aad-templatespec.bicep` template that is specifically designed for Azure AD-joined AVD session hosts that need to pass all health checks without any domain join requirements.

## What Makes This Template Different

### 🆕 Fresh Template Features
- **Azure AD join only** - No domain join attempts or configurations
- **Registry pre-configuration** - Sets up the environment before AVD agent installation
- **Health check optimization** - Configures registry settings to prevent domain health check failures
- **Post-deployment configuration** - Ensures all health checks pass after AVD agent installation
- **System-assigned managed identity** - Enhanced security configuration
- **Trusted Launch support** - Modern VM security features enabled by default

### 🔧 Technical Implementation
1. **Pre-configuration Extension**: Sets registry values to indicate Azure AD-only environment
2. **Azure AD Join Extension**: Properly joins the VM to Azure AD
3. **AVD Agent DSC Extension**: Installs AVD agent with minimal required parameters
4. **Post-configuration Extension**: Disables domain health checks and ensures compliance

## Deployment Steps

### Step 1: Prepare the Template
1. **Update VNet Resource Group** (line 95 in template):
   ```bicep
   scope: resourceGroup('YourVNetResourceGroup') // Change from 'EST2_SharedResources'
   ```

### Step 2: Deploy Template Spec
```powershell
# Deploy the fresh template spec as version 2.0
.\Deploy-FreshAADTemplateSpec.ps1 `
    -ResourceGroupName "YourTemplateSpecRG" `
    -TemplateSpecName "YourTemplateSpecName" `
    -Location "YourLocation" `
    -Version "2.0"
```

### Step 3: Update Runbook
Update your runbook to use the new template spec version:
```powershell
$TemplateSpecVersion = "2.0"  # Change from previous version
```

### Step 4: Test Deployment
Run your runbook and monitor for successful deployment.

## Expected Results

### ✅ Successful Deployment Indicators
- **No DSC extension errors** - Template uses only supported parameters
- **Successful Azure AD join** - AADLoginForWindows extension installs successfully
- **AVD agent registration** - Session host appears in host pool
- **Health checks pass** - All health checks show as passing, including:
  - DomainJoinedCheck: PASS
  - DomainTrustCheck: PASS
  - AADJoinedCheck: PASS
  - Other standard health checks: PASS

### 📊 Registry Configuration Applied
The template automatically configures these registry settings:

**Pre-configuration (before AVD agent):**
```
HKLM:\SOFTWARE\Microsoft\RDInfraAgent
├── IsRegistered = 0 (DWORD)
└── RegistrationToken = "" (STRING)

HKLM:\SOFTWARE\Microsoft\Windows Virtual Desktop
├── AADJoined = 1 (DWORD)
└── DomainJoined = 0 (DWORD)
```

**Post-configuration (after AVD agent):**
```
HKLM:\SOFTWARE\Microsoft\RDInfraAgent\HealthCheck
├── DomainJoinedCheckDisabled = 1 (DWORD)
├── DomainTrustCheckDisabled = 1 (DWORD)
└── AADJoinedCheck = 1 (DWORD)
```

## Troubleshooting

### If Health Checks Still Fail
1. **Check deployment logs** in Azure Portal under VM > Extensions
2. **Verify registry settings** using the diagnostic script:
   ```powershell
   .\Fix-AVDDomainHealthChecks.ps1 -HostPoolName "YourHostPool" -ResourceGroupName "YourAVDRG"
   ```
3. **Check session host status** in AVD admin center

### If Extension Failures Occur
1. **Check extension logs** in VM > Extensions > View detailed status
2. **Verify network connectivity** to Azure AD and AVD endpoints
3. **Check VM system-assigned identity** is properly configured

### Manual Registry Fix (if needed)
If the automated configuration doesn't work, you can manually apply the registry settings:
```powershell
# Run on the session host VM
$regPath = 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent\HealthCheck'
if (!(Test-Path $regPath)) { New-Item -Path $regPath -Force }
Set-ItemProperty -Path $regPath -Name 'DomainJoinedCheckDisabled' -Value 1 -Type DWord
Set-ItemProperty -Path $regPath -Name 'DomainTrustCheckDisabled' -Value 1 -Type DWord
Set-ItemProperty -Path $regPath -Name 'AADJoinedCheck' -Value 1 -Type DWord
Restart-Service -Name 'RDAgentBootLoader' -Force
```

## Validation Commands

### Check Template Spec Deployment
```powershell
Get-AzTemplateSpec -Name "YourTemplateSpecName" -ResourceGroupName "YourTemplateSpecRG" -Version "2.0"
```

### Verify Session Host Status
```powershell
Get-AzWvdSessionHost -HostPoolName "YourHostPool" -ResourceGroupName "YourAVDRG"
```

### Check VM Extensions
```powershell
Get-AzVMExtension -ResourceGroupName "YourVMRG" -VMName "YourVMName"
```

## Key Differences from Previous Templates

| Feature | Previous Templates | Fresh Template |
|---------|-------------------|----------------|
| Domain Configuration | Attempted to handle both scenarios | Azure AD only, no domain logic |
| Registry Setup | Manual or post-deployment | Automated pre and post configuration |
| Health Checks | Reactive fixes | Proactive prevention |
| Extension Order | Basic dependencies | Optimized extension sequence |
| Error Handling | Generic | Azure AD-specific optimizations |

## Success Criteria

After deployment with this fresh template, you should see:
- ✅ Session host status: "Available"
- ✅ Health checks: All passing
- ✅ Domain health checks: Disabled/passing
- ✅ Azure AD join: Successful
- ✅ No extension errors in deployment logs

This fresh template is specifically engineered to eliminate the domain health check issues you've been experiencing while ensuring proper Azure AD join functionality.
