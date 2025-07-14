# URGENT FIX: DomainJoinedCheck & DomainTrustCheck Failures

## 🚨 Problem Summary
Your Azure AD joined session hosts are failing domain health checks, preventing connections. This is a known issue where AVD agent incorrectly performs domain checks on Azure AD-only VMs.

## 🎯 **IMMEDIATE SOLUTIONS** (Try in order)

### Solution 1: Quick Fix - Force Health Check Timeout ⏱️
**Estimated Time: 30-60 minutes**

1. **Run the diagnostic script:**
   ```powershell
   .\Fix-AVDDomainHealthChecks.ps1 -HostPoolName "vdpool-RBAL-use2" -ResourceGroupName "YourRG" -SessionHostName "YourSessionHost" -ApplyFix
   ```

2. **Wait 30-60 minutes** for domain health checks to timeout naturally

3. **Check status:**
   ```powershell
   Get-AzWvdSessionHost -HostPoolName "vdpool-RBAL-use2" -ResourceGroupName "YourRG" -Name "YourSessionHost"
   ```

### Solution 2: Deploy Updated Template Spec (Version 1.7) 🔧
**Estimated Time: 15-30 minutes per VM**

1. **Deploy new Template Spec with aggressive domain check disabling:**
   ```powershell
   New-AzTemplateSpec -ResourceGroupName "YourTemplateSpecRG" -Name "YourTemplateSpecName" -Version "1.7" -Location "YourLocation" -TemplateFile "c:\Users\srimmer\Downloads\sample-templatespec.bicep"
   ```

2. **Update runbook parameter:**
   - Change `TemplateSpecVersion` to "1.7"

3. **Test with one session host rebuild**

### Solution 3: Alternative Template Spec (CustomScript Approach) 🛠️
**Estimated Time: 20-40 minutes per VM**

If DSC continues to cause issues, use the alternative template:

1. **Deploy alternative Template Spec:**
   ```powershell
   New-AzTemplateSpec -ResourceGroupName "YourTemplateSpecRG" -Name "YourTemplateSpecName-Alt" -Version "2.0" -Location "YourLocation" -TemplateFile "sample-templatespec-alternative.bicep"
   ```

2. **Update runbook to use alternative template:**
   - Change `TemplateSpecName` to "YourTemplateSpecName-Alt"
   - Change `TemplateSpecVersion` to "2.0"

### Solution 4: Manual AVD Agent Re-registration 🔄
**Estimated Time: 10-15 minutes per VM**

For existing VMs without rebuilding:

1. **Get registration token:**
   ```powershell
   $token = Get-AzWvdHostPoolRegistrationToken -HostPoolName "vdpool-RBAL-use2" -ResourceGroupName "YourRG"
   if (-not $token.Token) {
       $ExpirationTime = $((Get-Date).ToUniversalTime().AddHours(4).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
       $token = New-AzWvdRegistrationInfo -ResourceGroupName "YourRG" -HostPoolName "vdpool-RBAL-use2" -ExpirationTime $ExpirationTime
   }
   ```

2. **On each affected VM, run:**
   ```powershell
   # Stop AVD services
   Stop-Service -Name "RDAgentBootLoader" -Force
   Stop-Service -Name "Remote Desktop Agent Loader" -Force
   
   # Update registry for Azure AD join
   $regKey = 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent'
   Set-ItemProperty -Path $regKey -Name 'UseAADJoin' -Value 1
   Set-ItemProperty -Path $regKey -Name 'RegistrationToken' -Value "TOKEN_FROM_STEP_1"
   Set-ItemProperty -Path $regKey -Name 'IsRegistered' -Value 0
   
   # Restart services
   Start-Service -Name "RDAgentBootLoader"
   Start-Service -Name "Remote Desktop Agent Loader"
   ```

## 🔍 **ROOT CAUSE ANALYSIS**

The issue occurs because:
1. **DSC Extension Configuration**: The AVD DSC module doesn't properly disable domain health checks for Azure AD environments
2. **Health Check Logic**: AVD agent assumes domain join is required even when `aadJoin: true`
3. **Registry Settings**: Missing or incorrect registry values for Azure AD join mode

## 📋 **CHANGES MADE**

### Template Spec Updates (Version 1.7):
```bicep
properties: {
  hostPoolName: hostPoolName
  registrationInfoToken: registrationInfoToken
  aadJoin: empty(domainToJoin) && enableAzureADJoin ? true : false
  domainJoined: empty(domainToJoin) ? false : true  // ← NEW: Explicitly disable domain checks
}
```

### Alternative Template (Version 2.0):
- Uses **CustomScriptExtension** instead of DSC
- Manually installs AVD agent with correct Azure AD settings
- Bypasses DSC domain checking logic entirely

## ✅ **EXPECTED RESULTS**

After implementing any solution:
1. **Session Host Status**: "Available"
2. **Health Checks**: No DomainJoinedCheck/DomainTrustCheck failures
3. **User Connections**: Should work normally
4. **Azure AD Join**: VM remains Azure AD joined

## 🚨 **EMERGENCY WORKAROUND**

If all else fails, manually disable health checks:

1. **On each VM, modify registry:**
   ```powershell
   # Disable domain health checks entirely
   $regKey = 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent'
   Set-ItemProperty -Path $regKey -Name 'DisableDomainHealthCheck' -Value 1
   Restart-Service -Name "RDAgentBootLoader" -Force
   ```

## 📞 **RECOMMENDED ACTION PLAN**

1. **Immediate (0-1 hour)**: Try Solution 1 (Force timeout) + Solution 4 (Manual re-registration)
2. **Short-term (1-4 hours)**: Deploy Template Spec 1.7 and rebuild 1-2 test VMs
3. **If persistent**: Switch to Alternative Template Spec 2.0
4. **Last resort**: Manual registry modification

## 📊 **SUCCESS METRICS**

Monitor these after each solution:
```powershell
# Check session host health
Get-AzWvdSessionHost -HostPoolName "vdpool-RBAL-use2" -ResourceGroupName "YourRG" | Where-Object {$_.Status -ne "Available"}

# Check for domain health check failures
Get-AzWvdSessionHost -HostPoolName "vdpool-RBAL-use2" -ResourceGroupName "YourRG" | Select-Object Name, Status, @{Name="DomainChecks";Expression={($_.SessionHostHealthCheckResult | Where-Object {$_.HealthCheckName -like "*Domain*"}).HealthCheckResult}}
```

**This should resolve the persistent domain health check failures once and for all!**
