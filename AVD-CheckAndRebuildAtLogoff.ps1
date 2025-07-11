<#
This script is designed to rebuild a Personal VM after a user has logged off and/or no previous sessions have been noted in the past 
$ifNotUsedInHrs value. This prevents rebuild of VMs that have been manually assigned but not used. The scenarios where this will help
are:
1. Sensitive data left behind and need to ensure VM is rebuilt but will be unassigned or auto assigned when complete
2. Personal Host Pool with FSLogix for Profiles and to save cost only have subset of VMs for active users and not all all users in the 
   organization with possibly many powered down or not in use.

PARAMETERS:
- enableAzureADJoin: Set to $false to disable Azure AD Join extension if experiencing connectivity issues (default: $false)
  Azure AD Join requires network connectivity to Azure AD endpoints. If experiencing errors like 0x801c002d, 
  disable this feature and troubleshoot network connectivity separately.

#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$CloudEnvironment,	
    [Parameter(Mandatory)]
    [string]$HostPoolName,
    [Parameter(Mandatory)]
    [string]$avdRG,
    [Parameter(Mandatory)]
    [string]$SubscriptionId,
    [Parameter(Mandatory)]
    [string]$TemplateSpecName,
    [Parameter(Mandatory)]
    [string]$TemplateSpecVersion,
    [Parameter(Mandatory)]
    [string]$TemplateSpecRG,
    [Parameter(Mandatory)]
    [string]$KeyVaultName,
    [Parameter(Mandatory)]
    [string]$KeyVaultVMAdmin,
    [Parameter(Mandatory)]
    [string]$WorkspaceId,
    [Parameter(Mandatory)]
    [string]$IfNotUsedInHrs,
    [Parameter(Mandatory)]
    [string]$imageId,
    [Parameter(Mandatory = $false)]
    [bool]$enableAzureADJoin = $false
)

Connect-AzAccount -Identity -Environment $CloudEnvironment -Subscription $SubscriptionId | Out-Null

# Wait for role assignments to propagate (up to 5 minutes)
$maxWaitTime = 300  # 5 minutes
$waitInterval = 30  # 30 seconds
$elapsed = 0

Write-Output "Verifying subscription access and waiting for role assignments to propagate..."
do {
    try {
        # Test subscription access
        $context = Get-AzContext
        if ($context -and $context.Subscription.Id -eq $SubscriptionId) {
            Write-Output "Successfully connected to subscription: $SubscriptionId"
            break
        }
        else {
            throw "Context not established or wrong subscription"
        }
    }
    catch {
        if ($elapsed -ge $maxWaitTime) {
            Write-Error "Failed to establish subscription access after $maxWaitTime seconds. Error: $($_.Exception.Message)"
            Write-Output "Current context: $(Get-AzContext | Out-String)"
            throw "Subscription access verification failed"
        }
        
        Write-Output "Waiting for role assignments to propagate... ($elapsed/$maxWaitTime seconds)"
        Start-Sleep -Seconds $waitInterval
        $elapsed += $waitInterval
        
        # Retry connection
        try {
            Connect-AzAccount -Identity -Environment $CloudEnvironment -Subscription $SubscriptionId -Force | Out-Null
        }
        catch {
            Write-Output "Retry connection failed: $($_.Exception.Message)"
        }
    }
} while ($elapsed -lt $maxWaitTime)

###   FUNCTION: Replace VM   ###
Function Replace-AvdHost {
    param (
        $AdminVMPassword,
        $HostPoolName,
        $avdRG,
        $TemplateSpecId,
        $VM,
        $hostName,
        $index,
        $VMSize,
        $VNetName,
        $SubnetName,
        $adminUsername,
        $imageId
    )
    
    # Remove from AVD Host Pool and actual VM (Including Disk and NIC)
    Write-Output "...Removing Session Host from AVD"
    Remove-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $avdRG -Name $hostName -Force
    
    # Safely extract VM resource information with null checks
    if (-not $VM) {
        Write-Error "VM object is null, cannot proceed with removal"
        return
    }
    
    Write-Output "...Stopping VM"
    try {
        if ($VM.ResourceGroupName -and $VM.Name) {
            Stop-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Force | Out-Null
        }
        else {
            Write-Error "VM ResourceGroupName or Name is null: RG=$($VM.ResourceGroupName), Name=$($VM.Name)"
            return
        }
    }
    catch {
        Write-Error "Failed to stop VM: $($_.Exception.Message)"
    }
    
    # Safely extract NIC and Disk IDs
    $VMNicId = $null
    $VMDiskId = $null
    
    if ($VM.NetworkProfile -and $VM.NetworkProfile.NetworkInterfaces -and $VM.NetworkProfile.NetworkInterfaces.Count -gt 0) {
        $VMNicId = $VM.NetworkProfile.NetworkInterfaces[0].id
    }
    
    if ($VM.StorageProfile -and $VM.StorageProfile.OsDisk -and $VM.StorageProfile.OsDisk.ManagedDisk) {
        $VMDiskId = $VM.StorageProfile.OsDisk.ManagedDisk.Id
    }
    
    Write-Output "...Removing VM"
    try {
        Remove-AzVM -Name $VM.Name -ForceDeletion $true -ResourceGroupName $VM.ResourceGroupName -Force | Out-Null
    }
    catch {
        Write-Error "Failed to remove VM: $($_.Exception.Message)"
    }
    
    if ($VMNicId) {
        Write-Output "...Removing NIC"
        try {
            Remove-AzResource -ResourceId $VMNicId -Force -ApiVersion "2022-09-01" | Out-Null
        }
        catch {
            Write-Error "Failed to remove NIC: $($_.Exception.Message)"
        }
    }
    else {
        Write-Output "...Warning: NIC ID not found, skipping NIC removal"
    }
    
    if ($VMDiskId) {
        Write-Output "...Removing OS Disk"
        try {
            Remove-AzResource -ResourceId $VMDiskId -Force -ApiVersion "2024-03-02" | Out-Null
        }
        catch {
            Write-Error "Failed to remove OS Disk: $($_.Exception.Message)"
        }
    }
    else {
        Write-Output "...Warning: Disk ID not found, skipping disk removal"
    }
    
    # Ensure Host Pool Token exists and create if not
    Write-Output "...Getting Registration Token if doesn't exist (4hrs for deployment)"
    $HPToken = Get-AzWvdHostPoolRegistrationToken -HostPoolName $HostPoolName -ResourceGroupName $avdRG
    If ($null -eq $HPToken.Token) {
        # Create new token with 4-hour expiration for deployment
        $ExpirationTime = $((Get-Date).ToUniversalTime().AddHours(4).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
        $HPToken = New-AzWvdRegistrationInfo -ResourceGroupName $avdRG -HostPoolName $HostPoolName -ExpirationTime $ExpirationTime
        Write-Output "...Created new registration token, expires: $ExpirationTime"
    }
    else {
        # Check if token is expiring soon (within 30 minutes)
        $tokenExpiry = [DateTime]::Parse($HPToken.ExpirationTime)
        $timeUntilExpiry = $tokenExpiry - (Get-Date).ToUniversalTime()
        if ($timeUntilExpiry.TotalMinutes -lt 30) {
            Write-Output "...Token expires soon, creating new token"
            $ExpirationTime = $((Get-Date).ToUniversalTime().AddHours(4).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
            $HPToken = New-AzWvdRegistrationInfo -ResourceGroupName $avdRG -HostPoolName $HostPoolName -ExpirationTime $ExpirationTime
            Write-Output "...Created new registration token, expires: $ExpirationTime"
        }
        else {
            Write-Output "...Using existing token, expires: $($HPToken.ExpirationTime)"
        }
    }
    # Token is now available for template deployment

    # Determine if this is an Azure Compute Gallery image or marketplace image
    $isGalleryImage = $imageId -match "^/subscriptions/.*/resourceGroups/.*/providers/Microsoft\.Compute/galleries/.*/images/.*"
    
    if ($isGalleryImage) {
        Write-Output "Processing Azure Compute Gallery image: $imageId"
        
        # Parse gallery image ID - handle both with and without version
        $imageIdParts = $imageId -split '/'
        if ($imageIdParts.Length -lt 11) {
            Write-Error "Invalid gallery image ID format: $imageId"
            return
        }
        
        $resourceGroupName = $imageIdParts[4]
        $galleryName = $imageIdParts[8]
        $imageName = $imageIdParts[10]
        
        # Check if version is specified (length 13+) or if we need latest
        if ($imageIdParts.Length -ge 13 -and $imageIdParts[12] -ne "" -and $imageIdParts[12] -ne "latest") {
            $imageVersion = $imageIdParts[12]
            Write-Output "Using specified gallery image version: $imageVersion"
        } 
        else {
            Write-Output "Fetching the latest version for gallery image..."
            # Get the latest version of the gallery image
            try {
                $latestImageVersion = Get-AzGalleryImageVersion -ResourceGroupName $resourceGroupName -GalleryName $galleryName -GalleryImageDefinitionName $imageName -ErrorAction Stop | Sort-Object -Property {[System.Version]$_.Name} -Descending | Select-Object -First 1
                if ($latestImageVersion) {
                    $imageVersion = $latestImageVersion.Name
                    $imageId = "/subscriptions/$($imageIdParts[2])/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/galleries/$galleryName/images/$imageName/versions/$imageVersion"
                    Write-Output "Latest gallery version found and updated imageId: $imageId"
                } 
                else {
                    Write-Error "Unable to fetch the latest version for the gallery image: $imageName"
                    return
                }
            }
            catch {
                Write-Error "Failed to retrieve gallery image versions: $($_.Exception.Message)"
                return
            }
        }
        
        # Verify gallery image exists
        try {
            $galleryImageVersion = Get-AzGalleryImageVersion -ResourceGroupName $resourceGroupName -GalleryName $galleryName -GalleryImageDefinitionName $imageName -Name $imageVersion -ErrorAction Stop
            Write-Output "Gallery image verified: $($galleryImageVersion.Id)"
        } 
        catch {
            Write-Error "Gallery image not found: $imageId. Error: $($_.Exception.Message)"
            return
        }
        
        # Template parameters for gallery image
        $templateParams = @{
            vmName = $hostName
            vmSize = $VMSize
            adminUsername = $adminUsername  
            adminPassword = $AdminVMPassword
            hostPoolName = $HostPoolName
            resourceGroupName = $avdRG
            vnetName = $VNetName
            subnetName = $SubnetName
            registrationInfoToken = $HPToken.Token
            useGalleryImage = $true
            imageId = $imageId
            imagePublisher = ""
            imageOffer = ""
            imageSku = ""
            imageVersion = ""
            securityType = "TrustedLaunch"
            enableSecureBoot = $true
            enableVtpm = $true
            enableAzureADJoin = $enableAzureADJoin
            # Domain join parameters - explicitly set to empty for Azure AD join
            domainToJoin = ""
            ouPath = ""
            domainUsername = ""
            domainPassword = ""
        }
    } 
    else {
        Write-Output "Processing marketplace image: $imageId"
        
        # Handle marketplace image format (Publisher:Offer:Sku:Version)
        $imageIdParts = $imageId -split ':'
        if ($imageIdParts.Length -eq 4) {
            $imagePublisher = $imageIdParts[0]
            $imageOffer = $imageIdParts[1]
            $imageSku = $imageIdParts[2]
            $imageVersionMarketplace = $imageIdParts[3]
        } 
        else {
            Write-Error "Invalid marketplace image format. Expected format: Publisher:Offer:Sku:Version but got: $imageId"
            return
        }
        
        # Verify marketplace image details
        if (-not $imagePublisher -or -not $imageOffer -or -not $imageSku -or -not $imageVersionMarketplace) {
            Write-Error "Invalid marketplace image format: $imageId. Unable to extract Publisher, Offer, SKU, or Version."
            return
        }
        
        Write-Output "Marketplace image details - Publisher: $imagePublisher, Offer: $imageOffer, SKU: $imageSku, Version: $imageVersionMarketplace"
        
        # Template parameters for marketplace image
        $templateParams = @{
            vmName = $hostName
            vmSize = $VMSize
            adminUsername = $adminUsername  
            adminPassword = $AdminVMPassword
            hostPoolName = $HostPoolName
            resourceGroupName = $avdRG
            vnetName = $VNetName
            subnetName = $SubnetName
            registrationInfoToken = $HPToken.Token
            useGalleryImage = $false
            imageId = ""
            imagePublisher = $imagePublisher
            imageOffer = $imageOffer
            imageSku = $imageSku
            imageVersion = $imageVersionMarketplace
            securityType = "TrustedLaunch"
            enableSecureBoot = $true
            enableVtpm = $true
            enableAzureADJoin = $enableAzureADJoin
            # Domain join parameters - explicitly set to empty for Azure AD join
            domainToJoin = ""
            ouPath = ""
            domainUsername = ""
            domainPassword = ""
        }
        
        # Verify marketplace image exists
        try {
            $image = Get-AzVMImage -PublisherName $imagePublisher -Offer $imageOffer -Skus $imageSku -Location $VM.Location -Version $imageVersionMarketplace -ErrorAction Stop
            Write-Output "Marketplace image verified: $($image.Id)"
        } 
        catch {
            Write-Error "Marketplace image not found: Publisher: $imagePublisher, Offer: $imageOffer, Sku: $imageSku, Version: $imageVersionMarketplace"
            return
        }
    }

    Write-Output "...Submitting Spec to rebuild VM ($TemplateSpecName $TemplateSpecVersion)"
    try {
        $deployment = New-AzResourceGroupDeployment `
            -ResourceGroupName $avdRG `
            -TemplateSpecId $TemplateSpecId `
            -TemplateParameterObject $templateParams `
            -Name "$TemplateSpecName-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
            -Verbose `
            -ErrorAction Stop
        
        Write-Output "Template deployment completed successfully. Deployment name: $($deployment.DeploymentName)"
        
        # Wait for VM to be ready and check AVD agent status
        Write-Output "...Waiting for VM deployment to complete and checking AVD registration..."
        $maxWaitTime = 900  # 15 minutes
        $checkInterval = 30 # 30 seconds
        $elapsed = 0
        $vmRegistered = $false
        
        while ($elapsed -lt $maxWaitTime -and -not $vmRegistered) {
            Start-Sleep -Seconds $checkInterval
            $elapsed += $checkInterval
            
            try {
                # Check if session host is registered and available
                $newSessionHost = Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $avdRG -Name $hostName -ErrorAction SilentlyContinue
                if ($newSessionHost -and $newSessionHost.Status -eq "Available") {
                    Write-Output "✅ VM successfully registered and available in AVD host pool"
                    $vmRegistered = $true
                }
                elseif ($newSessionHost) {
                    Write-Output "...Session host status: $($newSessionHost.Status) - waiting... ($elapsed/$maxWaitTime seconds)"
                }
                else {
                    Write-Output "...Session host not yet registered - waiting... ($elapsed/$maxWaitTime seconds)"
                }
            }
            catch {
                Write-Output "...Checking registration status... ($elapsed/$maxWaitTime seconds)"
            }
        }
        
        if (-not $vmRegistered) {
            Write-Warning "⚠️ VM deployment completed but AVD registration may not be complete. Check session host status in Azure Portal."
        }
    }
    catch {
        Write-Error "Template deployment failed: $($_.Exception.Message)"
        throw
    }
}

####   MAIN SCRIPT   ####
Write-Output "Getting AVD Session Hosts where user is assigned..."
$SessionHosts = Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $avdRG | Where-Object AssignedUser -ne $null

Foreach ($Sessionhost in $SessionHosts) {
    $assignedUser = $SessionHost.AssignedUser
    # Get index, short name and sessionhost name from hostpoolname/hostname.fqdn.com
    $hostName = ($SessionHost.Name -split '/')[1]
    $hostShortName = ($hostName -split "\.")[0]
    $index = ($hostShortName -split "-")[1]
    Write-Output "Assigned - $assignedUser`n...checking session status on $hostName"
    $session = Get-AzWvdUserSession -HostPoolName $HostPoolName -ResourceGroupName $avdRG -SessionHostName ($Sessionhost.Name -split '/')[1]
    
    Write-Output "...Session Status:" $session.SessionState

    # Ensure user has logged in at least once in last X hours
    $Query = 'WVDConnections
    |where TimeGenerated > ago(' + $IfNotUsedInHrs + 'h)
    |where SessionHostName == "' + $hostName + '"
    |where State == "Completed"
    |where UserName == "' + $assignedUser + '"
    |sort by TimeGenerated asc, CorrelationId'
    
    $PrevSessions = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceId -Query $Query | Select-Object -ExpandProperty Results
    If ($null -ne $PrevSessions) { 
        $PrevSessionTime = [datetime]$PrevSessions[-1].TimeGenerated
        $PrevUsed = $true 
    }
    else { 
        $PrevSessionTime = "No logons found in Log Analytics in past $IfNotUsedInHrs hrs (Logging can be delayd!)"
        $PrevUsed = $false 
    }
    Write-Output "...Last Logon: $PrevSessionTime"

    If (($session.SessionState -ne "Active") -and ($session.SessionState -ne "Disconnected") -and ($session.SessionState -ne "Pending") -and ($PrevUsed)) {
      
        Write-Output "...Session State null: No active sessions, rebuild!" -ForegroundColor Green

        # Remove VM including host pool registration
        Write-Output "...Getting Admin Passwords from Keyvault"
        try {
            $AdminVMPassword = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultVMAdmin -AsPlainText -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to retrieve admin password from Key Vault: $($_.Exception.Message)"
            Write-Output "Key Vault: $KeyVaultName, Secret: $KeyVaultVMAdmin"
            continue
        }
        
        Write-Output "...Getting VM information"
        try {
            $VM = Get-AzVM -Name $hostShortName -ErrorAction Stop
            if (-not $VM) {
                Write-Error "VM not found: $hostShortName"
                continue
            }
        }
        catch {
            Write-Error "Failed to retrieve VM information for: $hostShortName. Error: $($_.Exception.Message)"
            continue
        }
        
        $adminUsername = $VM.OsProfile.AdminUsername
        Write-Output "...Getting Template Spec ID"
        try {
            $TemplateSpecId = (Get-AzTemplateSpec -Name $TemplateSpecName -ResourceGroupName $TemplateSpecRG -Version $TemplateSpecVersion -ErrorAction Stop).Versions.Id
        }
        catch {
            Write-Error "Failed to retrieve Template Spec: $TemplateSpecName. Error: $($_.Exception.Message)"
            continue
        }
        
        $VMSize = $VM.HardwareProfile.VmSize
        
        # Safely extract network information with null checks
        if ($VM.NetworkProfile -and $VM.NetworkProfile.NetworkInterfaces -and $VM.NetworkProfile.NetworkInterfaces.Count -gt 0) {
            $nicId = $VM.NetworkProfile.NetworkInterfaces[0].Id
            try {
                $nic = Get-AzNetworkInterface -ResourceId $nicId -ErrorAction Stop
                if ($nic.IpConfigurations -and $nic.IpConfigurations.Count -gt 0 -and $nic.IpConfigurations[0].Subnet) {
                    $vnetId = ($nic.IpConfigurations[0].Subnet.Id -split '/subnets/')[0]
                    $vnet = Get-AzResource -ResourceId $vnetId -ErrorAction Stop
                    $VNetName = $vnet.Name
                    $SubnetName = $nic.IpConfigurations[0].Subnet.Id.Split('/')[-1]
                }
                else {
                    Write-Error "Unable to extract subnet information from NIC: $nicId"
                    continue
                }
            }
            catch {
                Write-Error "Failed to retrieve network interface information: $($_.Exception.Message)"
                continue
            }
        }
        else {
            Write-Error "VM does not have network interfaces configured: $hostShortName"
            continue
        }

        Replace-AvdHost -HostPoolName $HostPoolName -avdRG $avdRG -VM $VM -TemplateSpecId $TemplateSpecId -AdminVMPassword $AdminVMPassword -index $index -hostName $hostName -VMSize $VMSize -VNetName $VNetName -SubnetName $SubnetName -adminUsername $adminUsername -imageId $imageId
    }
    Else {
        Write-Output "...No Action Required"
    }
}

If ($null -eq $SessionHosts) { 
    Write-Output "No Session Hosts found with assigned users." 
}
