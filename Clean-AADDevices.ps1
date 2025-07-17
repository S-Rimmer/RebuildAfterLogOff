# Clean Up Azure AD Device Registrations for AVD Session Hosts
# Use this script to manually clean up stale Azure AD device registrations that may cause hostname conflicts

param(
    [Parameter(Mandatory=$false)]
    [string]$DeviceName,
    
    [Parameter(Mandatory=$false)]
    [string]$HostPoolName,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName,
    
    [switch]$ListOnly,
    
    [switch]$Force
)

Write-Output "=========================================="
Write-Output "Azure AD Device Cleanup for AVD"
Write-Output "=========================================="

try {
    # Check Azure connection
    $context = Get-AzContext
    if (-not $context) {
        Write-Error "Not connected to Azure. Run Connect-AzAccount first."
        exit 1
    }
    
    Write-Output "Connected to Azure: $($context.Account.Id)"
    Write-Output "Tenant: $($context.Tenant.Id)"
    Write-Output ""
    
    # Get access token for Microsoft Graph API
    $accessToken = (Get-AzAccessToken).Token
    $headers = @{
        'Authorization' = "Bearer $accessToken"
        'Content-Type' = 'application/json'
    }
    
    $devicesToClean = @()
    
    if ($DeviceName) {
        # Clean specific device
        Write-Output "🔍 Looking for specific device: $DeviceName"
        $devicesToClean += $DeviceName
    }
    elseif ($HostPoolName -and $ResourceGroupName) {
        # Get all session hosts from the host pool
        Write-Output "🔍 Getting session hosts from host pool: $HostPoolName"
        try {
            $sessionHosts = Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
            foreach ($sessionHost in $sessionHosts) {
                $hostName = ($sessionHost.Name -split '/')[1]
                $shortName = ($hostName -split "\.")[0]
                $devicesToClean += $shortName
            }
            Write-Output "Found $($devicesToClean.Count) session host(s) to check"
        }
        catch {
            Write-Error "Failed to get session hosts: $($_.Exception.Message)"
            exit 1
        }
    }
    else {
        Write-Error "Please provide either -DeviceName or both -HostPoolName and -ResourceGroupName"
        Write-Output ""
        Write-Output "Examples:"
        Write-Output "  .\Clean-AADDevices.ps1 -DeviceName 'avd-vm-01'"
        Write-Output "  .\Clean-AADDevices.ps1 -HostPoolName 'MyHostPool' -ResourceGroupName 'MyAVDRG'"
        Write-Output "  .\Clean-AADDevices.ps1 -HostPoolName 'MyHostPool' -ResourceGroupName 'MyAVDRG' -ListOnly"
        exit 1
    }
    
    Write-Output ""
    Write-Output "🔍 Searching for Azure AD devices..."
    
    $foundDevices = @()
    
    foreach ($deviceName in $devicesToClean) {
        try {
            Write-Output "Checking device: $deviceName"
            
            # Search for device by display name
            $devicesUri = "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$deviceName'"
            $response = Invoke-RestMethod -Uri $devicesUri -Headers $headers -Method Get -ErrorAction SilentlyContinue
            
            if ($response.value -and $response.value.Count -gt 0) {
                foreach ($device in $response.value) {
                    $foundDevices += [PSCustomObject]@{
                        DisplayName = $device.displayName
                        DeviceId = $device.deviceId
                        ObjectId = $device.id
                        OperatingSystem = $device.operatingSystem
                        LastActivity = $device.approximateLastSignInDateTime
                        IsCompliant = $device.isCompliant
                        IsManaged = $device.isManaged
                        TrustType = $device.trustType
                    }
                }
            }
        }
        catch {
            Write-Output "Warning: Could not search for device $deviceName`: $($_.Exception.Message)"
        }
    }
    
    if ($foundDevices.Count -eq 0) {
        Write-Output "✅ No Azure AD devices found matching the specified criteria"
        exit 0
    }
    
    Write-Output ""
    Write-Output "📋 Found $($foundDevices.Count) Azure AD device(s):"
    Write-Output "=========================================="
    
    foreach ($device in $foundDevices) {
        Write-Output "Device: $($device.DisplayName)"
        Write-Output "  Object ID: $($device.ObjectId)"
        Write-Output "  Device ID: $($device.DeviceId)"
        Write-Output "  OS: $($device.OperatingSystem)"
        Write-Output "  Last Activity: $($device.LastActivity)"
        Write-Output "  Trust Type: $($device.TrustType)"
        Write-Output "  Is Compliant: $($device.IsCompliant)"
        Write-Output "  Is Managed: $($device.IsManaged)"
        Write-Output ""
    }
    
    if ($ListOnly) {
        Write-Output "✅ List-only mode: No devices were removed"
        exit 0
    }
    
    # Confirm deletion
    if (-not $Force) {
        $confirmation = Read-Host "Do you want to delete these $($foundDevices.Count) device(s)? (y/N)"
        if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
            Write-Output "❌ Operation cancelled by user"
            exit 0
        }
    }
    
    Write-Output "🗑️ Removing Azure AD devices..."
    
    $successCount = 0
    $failureCount = 0
    
    foreach ($device in $foundDevices) {
        try {
            Write-Output "Removing device: $($device.DisplayName)"
            $deleteUri = "https://graph.microsoft.com/v1.0/devices/$($device.ObjectId)"
            Invoke-RestMethod -Uri $deleteUri -Headers $headers -Method Delete -ErrorAction Stop
            Write-Output "✅ Successfully removed: $($device.DisplayName)"
            $successCount++
        }
        catch {
            Write-Output "❌ Failed to remove $($device.DisplayName): $($_.Exception.Message)"
            $failureCount++
        }
    }
    
    Write-Output ""
    Write-Output "=========================================="
    Write-Output "CLEANUP SUMMARY"
    Write-Output "=========================================="
    Write-Output "✅ Successfully removed: $successCount device(s)"
    if ($failureCount -gt 0) {
        Write-Output "❌ Failed to remove: $failureCount device(s)"
    }
    Write-Output ""
    
    if ($successCount -gt 0) {
        Write-Output "🎯 Next steps:"
        Write-Output "1. Wait 5-10 minutes for Azure AD replication"
        Write-Output "2. Retry your AVD session host deployment"
        Write-Output "3. The hostname conflict should be resolved"
    }
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
