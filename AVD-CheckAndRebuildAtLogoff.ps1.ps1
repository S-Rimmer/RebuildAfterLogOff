# VARIABLES NEEDED
$HostPoolName = "hp-eastus2-personal"
$avdRG = "rg-eastus2-AVDLab-Resources"
$TemplateSpecName = "AVD-Personal-Replace"
$TemplateSpecVersion = "1.0"
$TemplateSpecRG = "rg-eastus2-AVDLab-Manage"
$KeyVaultName = "kv-eastus2-AVDLab"
$KeyVaultVMAdmin = "AdminPassword"
$KeyVaultDomAdmin = "DomainAdminPassword"
$WorkspaceId = '66ca5d5a-0f86-4c6c-9dcb-7cd5135f3c61'
$IfNotUsedInHrs = 3  # Rebuild if no sessions in past number of hours / prevents newly assigned from getting rebuilt


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
	[string]$HostPoolName,
    [Parameter(Mandatory)]
    [string]$avdRG,
    [Parameter(Mandatory)]
    [string]$TemplateSpecName,
    [Parameter(Mandatory)]
    [string]$TemplateSpecVersion,
    [Parameter(Mandatory)]
    [string]$TemplateSpecRG,
    [Parameter(Mandatory)]
    [string]$KeyVaultName,
    [Parameter(Mandatory)]
    [string]$KeyVaultAdmin,
    [Parameter(Mandatory)]
    [string]$KeyVaultDomAdmin,
    [Parameter(Mandatory)]
    [string]$WorkspaceId,
    [Parameter(Mandatory)]
    [string]$IfNotUsedInHrs
)

Connect-AzAccount -Identity -Environment $CloudEnvironment | Out-Null

###   FUNCTION: Replace VM   ###
Function Replace-AvdHost {
    param (
        $AdminVMPassword,
        $AdminDomainPassword,
        $HostPoolName,
        $avdRG,
        $TemplateSpecId,
        $VM,
        $hostName,
        $index
    )
    
    # Remove from AVD Host Pool and actual VM (Including Disk and NIC)
    Write-Host "...Removing Session Host from AVD"
    Remove-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $avdRG -Name $hostName -Force
    Write-Host "...Stoping VM"
    Stop-AzVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.Name -Force | Out-Null
    $VMNicId = $VM.NetworkProfile.NetworkInterfaces.id
    $VMDiskId = $VM.StorageProfile.OsDisk.ManagedDisk.Id
    Write-Host "...Removing VM"
    Remove-AzVM -Name $VM.Name -ForceDeletion $true -ResourceGroupName $VM.ResourceGroupName -Force | Out-Null
    Write-Host "...Removing NIC"
    Remove-AzResource -ResourceId $VMNicId -Force | Out-Null
    Write-Host "...Removing OS Disk"
    Remove-AzResource -ResourceId $VMDiskId -Force | Out-Null
    
    
    # Ensure Host Pool Token exists and create if not
    Write-Host "...Getting Registration Token if doesn't exist (2hrs)"
    $HPToken = Get-AzWvdHostPoolRegistrationToken -HostPoolName $HostPoolName -ResourceGroupName $avdRG
    If($HPToken.Token -eq $null){
        $ExpirationTime = $((Get-Date).ToUniversalTime().AddHours(2).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
        $HPToken = New-AzWvdRegistrationInfo -ResourceGroupName $avdRG -HostPoolName $HostPoolName -ExpirationTime $ExpirationTime
        }
    $HPTokenSecure = ConvertTo-SecureString $HPToken.Token -AsPlainText -Force

    # Call up template spec to rebuild
    $params = @{
     vmInitialNumber = [int]$index;
     vmAdministratorAccountPassword = $AdminVMPassword;
     administratorAccountPassword = $AdminDomainPassword;
     hostPoolToken = $HPToken.Token
    }
    Write-Host "...Submitting Template Spec to rebuild VM ($TemplateSpecName $TemplateSpecVersion)"
    New-AzResourceGroupDeployment `
        -ResourceGroupName $avdRG `
        -TemplateSpecId $TemplateSpecId `
        -TemplateParameterObject $params | Out-Null
}

####   MAIN SCRIPT   ####
Write-Host "Getting AVD Session Hosts where user is assigned..."
$SessionHosts = Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $avdRG | where AssignedUser -ne $null

Foreach($Sessionhost in $SessionHosts){
    $assignedUser = $SessionHost.AssignedUser
    # Get index, short name and sessionhost name from hostpoolname/hostname.fqdn.com
    $hostName = ($SessionHost.Name -split '/')[1]
    $hostShortName = ($hostName -split "\.")[0]
    $index = ($hostShortName -split "-")[1]
    Write-Host "Assigned - $assignedUser`n...checking session status on $hostName"
    $session = Get-AzWvdUserSession -HostPoolName $HostPoolName -ResourceGroupName $avdRG -SessionHostName ($Sessionhost.Name -split '/')[1]
    
    Write-Host "...Session Status:" $session.SessionState

    # Ensure user has logged in at least once in last X hours
    $Query = 'WVDConnections
    |where TimeGenerated > ago(' + $IfNotUsedInHrs +'h)
    |where SessionHostName == "' + $hostName + '"
    |where State == "Completed"
    |where UserName == "' + $assignedUser + '"
    |sort by TimeGenerated asc, CorrelationId'
    
    $PrevSessions = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceId -Query $Query | select -ExpandProperty Results
    If($PrevSessions -ne $null){$PrevSessionTime = [datetime]$PrevSessions[-1].TimeGenerated; $PrevUsed = $true}
    else{$PrevSessionTime = "No logons found in Log Analytics in past $IfNotUsedInHrs hrs (Logging can be delayd!)"; $PrevUsed = $false}
    Write-Host "...Last Logon: $PrevSessionTime"

    If (($session.SessionState -ne "Active") -and ($session.SessionState -ne "Disconnected") -and ($session.SessionState -ne "Pending") -and ($PrevUsed)) {
      
        Write-Host "...Session State null: No active sessions, rebuild!" -ForegroundColor Green

        # Remove VM including host pool registration
        Write-Host "...Getting Admin Passwords from Keyvault"
        $AdminDomainPassword = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultDomAdmin -AsPlainText
        $AdminVMPassword = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $KeyVaultVMAdmin -AsPlainText
        Write-Host "...Getting VM information"
        $VM = Get-azVM -Name $hostShortName
        Write-Host "...Getting Template Spec ID"
        $TemplateSpecId = (Get-AzTemplateSpec -Name $TemplateSpecName -ResourceGroupName $TemplateSpecRG -Version $TemplateSpecVersion).Versions.Id
        Replace-AvdHost -HostPoolName $HostPoolName -avdRG $avdRG -VM $VM -TemplateSpecId $TemplateSpecId -AdminVMPassword $AdminVMPassword -AdminDomainPassword $AdminDomainPassword -index $index -hostName $hostName
        }
    Else {
        Write-Host "...No Action Required"
        }
}
If($SessionHosts -eq $null){Write-Host "No Session Hosts found with assigned users."}


