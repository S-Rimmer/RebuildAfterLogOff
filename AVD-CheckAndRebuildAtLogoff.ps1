<#
This script is designed to rebuild a Personal VM after a user has logged off and/or no previous sessions have been noted in the past 
$ifNotUsedInHrs value. This prevents rebuild of VMs that have been manually assigned but not used. The scenarios where this will help
are:
1. Sensitive data may be left behind and need to ensure VM is rebuilt but will be unassigned or auto assigned when complete
2. Personal Host Pool with FSLogix for Profiles and to save cost only have subset of VMs for active users and not all all users in the 
   organization with possibly many powered down or not in use.

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
    [string]$imageId
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
    Write-Output "...Stopping VM"
    Stop-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Force | Out-Null
    $VMNicId = $VM.NetworkProfile.NetworkInterfaces.id
    $VMDiskId = $VM.StorageProfile.OsDisk.ManagedDisk.Id
    Write-Output "...Removing VM"
    Remove-AzVM -Name $VM.Name -ForceDeletion $true -ResourceGroupName $VM.ResourceGroupName -Force | Out-Null
    Write-Output "...Removing NIC"
    Remove-AzResource -ResourceId $VMNicId -Force -ApiVersion "2022-09-01" | Out-Null
    Write-Output "...Removing OS Disk"
    Remove-AzResource -ResourceId $VMDiskId -Force -ApiVersion "2024-03-02" | Out-Null
    
    # Ensure Host Pool Token exists and create if not
    Write-Output "...Getting Registration Token if doesn't exist (2hrs)"
    $HPToken = Get-AzWvdHostPoolRegistrationToken -HostPoolName $HostPoolName -ResourceGroupName $avdRG
    If ($HPToken.Token -eq $null) {
        $ExpirationTime = $((Get-Date).ToUniversalTime().AddHours(2).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
        $HPToken = New-AzWvdRegistrationInfo -ResourceGroupName $avdRG -HostPoolName $HostPoolName -ExpirationTime $ExpirationTime
    }
    $HPTokenSecure = ConvertTo-SecureString $HPToken.Token -AsPlainText -Force

    # Determine if this is an Azure Compute Gallery image or marketplace image
    $isGalleryImage = $imageId -match "^/subscriptions/.*/resourceGroups/.*/providers/Microsoft\.Compute/galleries/.*/images/.*/versions/.*$"
    
    if ($isGalleryImage) {
        Write-Output "Processing Azure Compute Gallery image: $imageId"
        
        # Parse gallery image ID
        $imageIdParts = $imageId -split '/'
        $resourceGroupName = $imageIdParts[4]
        $galleryName = $imageIdParts[8]
        $imageName = $imageIdParts[10]
        
        # Check if version is specified or if we need latest
        if ($imageIdParts.Length -ge 13 -and $imageIdParts[12] -ne "") {
            $imageVersion = $imageIdParts[12]
            Write-Output "Using specified gallery image version: $imageVersion"
        } else {
            Write-Output "Fetching the latest version for gallery image..."
            # Get the latest version of the gallery image
            $latestImageVersion = Get-AzGalleryImageVersion -ResourceGroupName $resourceGroupName -GalleryName $galleryName -GalleryImageDefinitionName $imageName | Sort-Object -Property {[System.Version]$_.Name} -Descending | Select-Object -First 1
            if ($latestImageVersion) {
                $imageVersion = $latestImageVersion.Name
                $imageId = "/subscriptions/$($imageIdParts[2])/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/galleries/$galleryName/images/$imageName/versions/$imageVersion"
                Write-Output "Latest gallery version found and updated imageId: $imageId"
            } else {
                Write-Error "Unable to fetch the latest version for the gallery image: $imageName"
                return
            }
        }
        
        # Verify gallery image exists
        try {
            $galleryImageVersion = Get-AzGalleryImageVersion -ResourceGroupName $resourceGroupName -GalleryName $galleryName -GalleryImageDefinitionName $imageName -Name $imageVersion -ErrorAction Stop
            Write-Output "Gallery image verified: $($galleryImageVersion.Id)"
        } catch {
            Write-Error "Gallery image not found: $imageId. Error: $($_.Exception.Message)"
            return
        }
        
        # For gallery images, we use the imageId directly in template parameters
        $imageReference = @{
            id = $imageId
        }
    } else {
        Write-Output "Processing marketplace image: $imageId"
        
        # Handle marketplace image format (Publisher:Offer:Sku:Version)
        $imageIdParts = $imageId -split ':'
        if ($imageIdParts.Length -eq 4) {
            $imagePublisher = $imageIdParts[0]
            $imageOffer = $imageIdParts[1]
            $imageSku = $imageIdParts[2]
            $imageVersion = $imageIdParts[3]
        } else {
            Write-Error "Invalid marketplace image format. Expected format: Publisher:Offer:Sku:Version"
            return
        }
        
        # Verify marketplace image details
        if (-not $imagePublisher -or -not $imageOffer -or -not $imageSku -or -not $imageVersion) {
            Write-Error "Invalid marketplace image format: $imageId. Unable to extract Publisher, Offer, SKU, or Version."
            return
        }
        
        # Verify marketplace image exists
        try {
            $image = Get-AzVMImage -PublisherName $imagePublisher -Offer $imageOffer -Skus $imageSku -Location $VM.Location -Version $imageVersion -ErrorAction Stop
            Write-Output "Marketplace image verified: $($image.Id)"
        } catch {
            Write-Error "Marketplace image not found: Publisher: $imagePublisher, Offer: $imageOffer, Sku: $imageSku, Version: $imageVersion"
            return
        }
        
        # For marketplace images, we use the traditional structure
        $imageReference = @{
            publisher = $imagePublisher
            offer = $imageOffer
            sku = $imageSku
            version = $imageVersion
        }
    }

    # Build template parameters based on image type
    $params = @{
        vmName                = $hostName;
        vmSize                = $VMSize;
        adminUsername         = $adminUsername;
        adminPassword         = $AdminVMPassword;
        hostPoolName          = $HostPoolName;
        resourceGroupName     = $avdRG;
        location              = $VM.Location;
        vnetName              = $VNetName;
        subnetName            = $SubnetName;
        registrationInfoToken = $HPToken.Token
    }
    
    # Add image reference parameters based on image type
    if ($isGalleryImage) {
        $params.Add('imageId', $imageId)
        $params.Add('useGalleryImage', $true)
        Write-Output "Using Azure Compute Gallery image: $imageId"
    } else {
        $params.Add('imagePublisher', $imageReference.publisher)
        $params.Add('imageOffer', $imageReference.offer)
        $params.Add('imageSku', $imageReference.sku)
        $params.Add('imageVersion', $imageReference.version)
        $params.Add('useGalleryImage', $false)
        Write-Output "Using marketplace image: $($imageReference.publisher):$($imageReference.offer):$($imageReference.sku):$($imageReference.version)"
    }
    Write-Output "...Submitting Spec to rebuild VM ($TemplateSpecName $TemplateSpecVersion)"
    New-AzResourceGroupDeployment `
        -ResourceGroupName $avdRG `
        -TemplateSpecId $TemplateSpecId `
        -TemplateParameterObject $params `
        -Name $TemplateSpecName `
        -Verbose
}

####   MAIN SCRIPT   ####
Write-Output "Getting AVD Session Hosts where user is assigned..."
$SessionHosts = Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $avdRG | where AssignedUser -ne $null

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
    
    $PrevSessions = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceId -Query $Query | select -ExpandProperty Results
    If ($PrevSessions -ne $null) { $PrevSessionTime = [datetime]$PrevSessions[-1].TimeGenerated; $PrevUsed = $true }
    else { $PrevSessionTime = "No logons found in Log Analytics in past $IfNotUsedInHrs hrs (Logging can be delayd!)"; $PrevUsed = $false }
    Write-Output "...Last Logon: $PrevSessionTime"

    If (($session.SessionState -ne "Active") -and ($session.SessionState -ne "Disconnected") -and ($session.SessionState -ne "Pending") -and ($PrevUsed)) {
      
        Write-Output "...Session State null: No active sessions, rebuild!" -ForegroundColor Green

        # Remove VM including host pool registration
        Write-Output "...Getting Admin Passwords from Keyvault"
        $AdminVMPassword = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultVMAdmin -AsPlainText
        Write-Output "...Getting VM information"
        $VM = Get-azVM -Name $hostShortName
        $adminUsername = $VM.OsProfile.AdminUsername
        Write-Output "...Getting Template Spec ID"
        $TemplateSpecId = (Get-AzTemplateSpec -Name $TemplateSpecName -ResourceGroupName $TemplateSpecRG -Version $TemplateSpecVersion).Versions.Id
        $VMSize = $VM.HardwareProfile.VmSize
        $nicId = $VM.NetworkProfile.NetworkInterfaces[0].Id
        $nic = Get-AzNetworkInterface -ResourceId $nicId
        $vnetId = ($nic.IpConfigurations[0].Subnet.Id -split '/subnets/')[0]
        $vnet = Get-AzResource -ResourceId $vnetId
        $VNetName = $vnet.Name
        $SubnetName = $nic.IpConfigurations[0].Subnet.Id.Split('/')[-1]

        Replace-AvdHost -HostPoolName $HostPoolName -avdRG $avdRG -VM $VM -TemplateSpecId $TemplateSpecId -AdminVMPassword $AdminVMPassword -index $index -hostName $hostName -VMSize $VMSize -VNetName $VNetName -SubnetName $SubnetName -adminUsername $adminUsername -imageId $imageId
    }
    Else {
        Write-Output "...No Action Required"
    }
}
If ($SessionHosts -eq $null) { Write-Output "No Session Hosts found with assigned users." }