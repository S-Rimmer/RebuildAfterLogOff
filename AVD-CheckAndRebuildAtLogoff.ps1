<#
This script is designed to rebuild a Personal VM after a users has logged off and/or no previous sessions have been noted in the past 
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
    [string]$KeyVaultDomAdmin,
    [Parameter(Mandatory)]
    [string]$WorkspaceId,
    [Parameter(Mandatory)]
    [string]$IfNotUsedInHrs
)

Connect-AzAccount -Identity -Environment $CloudEnvironment -Subscription $SubscriptionId | Out-Null

###   FUNCTION: Replace VM   ###
Function Replace-AvdHost {
    param (
        $AdminVMPassword,
        $HostPoolName,
        $avdRG,
        $TemplateSpecId,
        $VM,
        $hostName,
        $index
    )
    
    # Remove from AVD Host Pool and actual VM (Including Disk and NIC)
    Write-Output "...Removing Session Host from AVD"
    Remove-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $avdRG -Name $hostName -Force
    Write-Output "...Stoping VM"
    Stop-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Force | Out-Null
    $VMNicId = $VM.NetworkProfile.NetworkInterfaces.id
    $VMDiskId = $VM.StorageProfile.OsDisk.ManagedDisk.Id
    Write-Output "...Removing VM"
    Remove-AzVM -Name $VM.Name -ForceDeletion $true -ResourceGroupName $VM.ResourceGroupName -Force | Out-Null
    Write-Output "...Removing NIC"
    Remove-AzResource -ResourceId $VMNicId -Force | Out-Null
    Write-Output "...Removing OS Disk"
    Remove-AzResource -ResourceId $VMDiskId -Force | Out-Null
    
    
    # Ensure Host Pool Token exists and create if not
    Write-Output "...Getting Registration Token if doesn't exist (2hrs)"
    $HPToken = Get-AzWvdHostPoolRegistrationToken -HostPoolName $HostPoolName -ResourceGroupName $avdRG
    If ($HPToken.Token -eq $null) {
        $ExpirationTime = $((Get-Date).ToUniversalTime().AddHours(2).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
        $HPToken = New-AzWvdRegistrationInfo -ResourceGroupName $avdRG -HostPoolName $HostPoolName -ExpirationTime $ExpirationTime
    }
    $HPTokenSecure = ConvertTo-SecureString $HPToken.Token -AsPlainText -Force

    # Call up template spec to rebuild
    $params = @{
        vmInitialNumber                = [int]$index;
        vmAdministratorAccountPassword = $AdminVMPassword;
        hostPoolToken                  = $HPToken.Token
    }
    Write-Output "...Submitting Template Spec to rebuild VM ($TemplateSpecName $TemplateSpecVersion)"
    New-AzResourceGroupDeployment `
        -ResourceGroupName $avdRG `
        -TemplateSpecId $TemplateSpecId `
        -TemplateParameterObject $params | Out-Null
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
        Write-Output "...Getting Template Spec ID"
        $TemplateSpecId = (Get-AzTemplateSpec -Name $TemplateSpecName -ResourceGroupName $TemplateSpecRG -Version $TemplateSpecVersion).Versions.Id
        Replace-AvdHost -HostPoolName $HostPoolName -avdRG $avdRG -VM $VM -TemplateSpecId $TemplateSpecId -AdminVMPassword $AdminVMPassword -index $index -hostName $hostName
    }
    Else {
        Write-Output "...No Action Required"
    }
}
If ($SessionHosts -eq $null) { Write-Output "No Session Hosts found with assigned users." }


