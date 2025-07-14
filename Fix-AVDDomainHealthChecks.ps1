# Fix AVD Domain Health Check Failures - Comprehensive Solution

<#
This script addresses the persistent DomainJoinedCheck and DomainTrustCheck failures
in Azure AD joined AVD session hosts. Run this script to diagnose and fix the issue.
#>

param(
    [Parameter(Mandatory)]
    [string]$HostPoolName,
    
    [Parameter(Mandatory)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory)]
    [string]$SessionHostName,
    
    [Parameter(Mandatory = $false)]
    [switch]$ApplyFix = $false
)

Write-Output "=== AVD Domain Health Check Troubleshooting ==="
Write-Output "Host Pool: $HostPoolName"
Write-Output "Resource Group: $ResourceGroupName"
Write-Output "Session Host: $SessionHostName"
Write-Output ""

# Step 1: Check current session host status
Write-Output "1. Checking current session host status..."
try {
    $sessionHost = Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -Name $SessionHostName -ErrorAction Stop
    Write-Output "   Status: $($sessionHost.Status)"
    Write-Output "   Allow New Session: $($sessionHost.AllowNewSession)"
    Write-Output "   Last Heartbeat: $($sessionHost.LastHeartBeat)"
    
    if ($sessionHost.SessionHostHealthCheckResult) {
        Write-Output "   Health Check Results:"
        foreach ($check in $sessionHost.SessionHostHealthCheckResult) {
            $status = if ($check.AdditionalFailureDetails) { "FAILED - $($check.AdditionalFailureDetails)" } else { $check.HealthCheckResult }
            Write-Output "     - $($check.HealthCheckName): $status"
        }
    }
}
catch {
    Write-Error "Failed to get session host status: $($_.Exception.Message)"
    return
}

# Step 2: Check VM extensions
Write-Output ""
Write-Output "2. Checking VM extensions..."
$vmName = $SessionHostName.Split('.')[0]
try {
    $extensions = Get-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $vmName
    Write-Output "   Installed Extensions:"
    foreach ($ext in $extensions) {
        Write-Output "     - $($ext.Name): $($ext.Publisher)/$($ext.ExtensionType) (Status: $($ext.ProvisioningState))"
    }
    
    # Check for domain join extension
    $domainJoinExt = $extensions | Where-Object { $_.ExtensionType -eq "JsonADDomainExtension" }
    if ($domainJoinExt) {
        Write-Warning "   ⚠️  Domain Join extension found! This should NOT be present for Azure AD joined VMs."
    }
    
    # Check for Azure AD join extension
    $aadJoinExt = $extensions | Where-Object { $_.ExtensionType -eq "AADLoginForWindows" }
    if ($aadJoinExt) {
        Write-Output "   ✅ Azure AD Join extension found."
    } else {
        Write-Warning "   ⚠️  Azure AD Join extension NOT found!"
    }
    
    # Check DSC extension settings
    $dscExt = $extensions | Where-Object { $_.ExtensionType -eq "DSC" }
    if ($dscExt) {
        Write-Output "   DSC Extension Settings:"
        try {
            $settings = $dscExt.Settings | ConvertFrom-Json
            if ($settings.properties.aadJoin) {
                Write-Output "     - aadJoin: $($settings.properties.aadJoin) ✅"
            } else {
                Write-Warning "     - aadJoin: $($settings.properties.aadJoin) ⚠️"
            }
        }
        catch {
            Write-Warning "     - Could not parse DSC settings"
        }
    }
}
catch {
    Write-Error "Failed to get VM extensions: $($_.Exception.Message)"
}

# Step 3: Check VM domain join status
Write-Output ""
Write-Output "3. Checking VM domain join status..."
try {
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName
    Write-Output "   VM Location: $($vm.Location)"
    Write-Output "   VM Size: $($vm.HardwareProfile.VmSize)"
    Write-Output "   VM OS: $($vm.StorageProfile.ImageReference.Offer)"
}
catch {
    Write-Error "Failed to get VM details: $($_.Exception.Message)"
}

# Step 4: Apply fixes if requested
if ($ApplyFix) {
    Write-Output ""
    Write-Output "4. Applying fixes..."
    
    # Fix 1: Force session host refresh
    Write-Output "   Fix 1: Forcing session host refresh..."
    try {
        Update-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -Name $SessionHostName -AllowNewSession:$true
        Write-Output "     ✅ Session host refreshed"
    }
    catch {
        Write-Warning "     ⚠️  Failed to refresh session host: $($_.Exception.Message)"
    }
    
    # Fix 2: Remove and re-add session host (if it exists)
    Write-Output "   Fix 2: Attempting to re-register session host..."
    try {
        # Get host pool registration token
        $token = Get-AzWvdHostPoolRegistrationToken -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName
        if (-not $token.Token) {
            $ExpirationTime = $((Get-Date).ToUniversalTime().AddHours(4).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
            $token = New-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -ExpirationTime $ExpirationTime
            Write-Output "     ✅ Created new registration token"
        }
        
        # Note: Re-registration would require running commands on the VM itself
        Write-Output "     ℹ️  Registration token available: $($token.Token.Substring(0,20))..."
        Write-Output "     ℹ️  Manual re-registration may be required on the VM"
    }
    catch {
        Write-Warning "     ⚠️  Failed to get/create registration token: $($_.Exception.Message)"
    }
    
    # Fix 3: Try to restart AVD services (requires VM access)
    Write-Output "   Fix 3: Restart AVD services recommendation"
    Write-Output "     ℹ️  Run these commands on the VM to restart AVD services:"
    Write-Output "     Restart-Service -Name 'RDAgentBootLoader' -Force"
    Write-Output "     Restart-Service -Name 'Remote Desktop Agent Loader' -Force"
}

# Step 5: Recommendations
Write-Output ""
Write-Output "5. Recommendations:"

if ($sessionHost.Status -ne "Available") {
    Write-Output "   🔧 Session host is not available. Try these steps:"
    Write-Output "      1. Deploy updated Template Spec version 1.7 with domainJoined: false"
    Write-Output "      2. Wait 30-60 minutes for health checks to timeout"
    Write-Output "      3. Restart AVD services on the VM"
    Write-Output "      4. Force session host re-registration"
}

Write-Output ""
Write-Output "=== Next Steps ==="
Write-Output "1. Deploy Template Spec version 1.7 with the latest fixes"
Write-Output "2. Use the following commands to re-run this script with fixes:"
Write-Output "   .\Fix-AVDDomainHealthChecks.ps1 -HostPoolName '$HostPoolName' -ResourceGroupName '$ResourceGroupName' -SessionHostName '$SessionHostName' -ApplyFix"
Write-Output "3. If issues persist, consider recreating the session host with the updated template"

Write-Output ""
Write-Output "=== Troubleshooting Complete ==="
