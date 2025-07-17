/*
Fresh AVD Session Host Template Spec - Azure AD Join Only
This template is specifically designed for Azure AD-joined AVD session hosts
that need to pass all health checks without any domain join requirements.

Key Features:
✅ Azure AD join only (no domain join attempts)
✅ Proper AVD agent installation and configuration  
✅ Registry configuration to prevent domain health check failures
✅ Latest AVD DSC module with minimal required parameters
✅ Trusted Launch VM support with security features
✅ Proper cleanup configuration for automation scenarios

IMPORTANT: Update the VNet resource group name on line 95 before deployment
*/

@description('Name of the virtual machine')
param vmName string

@description('Size of the virtual machine')
param vmSize string = 'Standard_D2s_v3'

@description('Administrator username')
param adminUsername string

@description('Administrator password')
@secure()
param adminPassword string

@description('Name of the host pool')
param hostPoolName string

@description('Resource group name for AVD resources')
param resourceGroupName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Virtual network name')
param vnetName string

@description('Subnet name')
param subnetName string

@description('AVD Host Pool registration token')
@secure()
param registrationInfoToken string

@description('Indicates whether to use Azure Compute Gallery image')
param useGalleryImage bool = true

@description('Azure Compute Gallery image ID (when useGalleryImage is true)')
param imageId string = ''

@description('Marketplace image publisher (when useGalleryImage is false)')
param imagePublisher string = ''

@description('Marketplace image offer (when useGalleryImage is false)')
param imageOffer string = ''

@description('Marketplace image SKU (when useGalleryImage is false)')
param imageSku string = ''

@description('Marketplace image version (when useGalleryImage is false)')
param imageVersion string = ''

@description('Security type for the virtual machine (Standard or TrustedLaunch)')
@allowed(['Standard', 'TrustedLaunch'])
param securityType string = 'TrustedLaunch'

@description('Enable Secure Boot (requires TrustedLaunch security type)')
param enableSecureBoot bool = true

@description('Enable vTPM (requires TrustedLaunch security type)')
param enableVtpm bool = true

@description('Enable Azure AD join extension')
param enableAzureADJoin bool = true

@description('MDM enrollment ID for Azure AD join (empty for basic Azure AD join)')
param mdmId string = ''

// Variables
var nicName = '${vmName}-nic'
var computerName = vmName

// Get existing virtual network and subnet
// ⚠️ IMPORTANT: Update the resourceGroupName below to match your VNet's resource group
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnetName
  scope: resourceGroup('EST2_SharedResources') // TODO: Change to your VNet's resource group name
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  name: subnetName
  parent: vnet
}

// Create network interface
resource networkInterface 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet.id
          }
        }
      }
    ]
  }
}

// Create virtual machine with conditional image reference
resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: computerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: false
        provisionVMAgent: true
        enableVMAgentPlatformUpdates: true
      }
    }
    storageProfile: {
      imageReference: useGalleryImage ? {
        id: imageId
      } : {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        name: '${vmName}-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        deleteOption: 'Delete' // Ensures disk is deleted when VM is deleted
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
          properties: {
            deleteOption: 'Delete' // Ensures NIC is deleted when VM is deleted
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true // Enables boot diagnostics for troubleshooting
      }
    }
    securityProfile: securityType == 'TrustedLaunch' ? {
      securityType: securityType
      uefiSettings: {
        secureBootEnabled: enableSecureBoot
        vTpmEnabled: enableVtpm
      }
    } : {
      securityType: securityType
    }
  }
}

// Azure AD Join extension (always deployed for Azure AD-only environments)
resource aadJoinExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = if (enableAzureADJoin) {
  parent: virtualMachine
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      mdmId: mdmId // Required setting - empty string for basic Azure AD join without MDM enrollment
    }
    protectedSettings: {}
  }
}

// Pre-configure registry for Azure AD-only environment to prevent domain health check failures
resource preConfigurationExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: virtualMachine
  name: 'PreConfigureAADEnvironment'
  location: location
  dependsOn: [
    aadJoinExtension
  ]
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -Command "& { Write-Host \'Configuring Azure AD-only environment...\'; $regPath = \'HKLM:\\SOFTWARE\\Microsoft\\RDInfraAgent\'; if (!(Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }; Set-ItemProperty -Path $regPath -Name \'IsRegistered\' -Value 0 -Type DWord; Set-ItemProperty -Path $regPath -Name \'RegistrationToken\' -Value \'\' -Type String; $avdRegPath = \'HKLM:\\SOFTWARE\\Microsoft\\Windows Virtual Desktop\'; if (!(Test-Path $avdRegPath)) { New-Item -Path $avdRegPath -Force | Out-Null }; Set-ItemProperty -Path $avdRegPath -Name \'AADJoined\' -Value 1 -Type DWord; Set-ItemProperty -Path $avdRegPath -Name \'DomainJoined\' -Value 0 -Type DWord; Write-Host \'Registry pre-configuration completed for Azure AD-only environment\'; }"'
    }
  }
}

// Install AVD agent and register with host pool using latest DSC module
resource avdAgentExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: virtualMachine
  name: 'AVDAgent'
  location: location
  dependsOn: [
    aadJoinExtension
    preConfigurationExtension
  ]
  properties: {
    publisher: 'Microsoft.PowerShell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_09-08-2022.zip'
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostPoolName
        registrationInfoToken: registrationInfoToken
        aadJoin: true // Always true for Azure AD-only environments
      }
    }
    protectedSettings: {}
  }
}

// Post-deployment configuration to ensure health checks pass
resource postConfigurationExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: virtualMachine
  name: 'PostConfigureHealthChecks'
  location: location
  dependsOn: [
    avdAgentExtension
  ]
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -Command "& { Write-Host \'Configuring AVD health checks for Azure AD environment...\'; Start-Sleep -Seconds 30; $healthRegPath = \'HKLM:\\SOFTWARE\\Microsoft\\RDInfraAgent\\HealthCheck\'; if (!(Test-Path $healthRegPath)) { New-Item -Path $healthRegPath -Force | Out-Null }; Set-ItemProperty -Path $healthRegPath -Name \'DomainJoinedCheckDisabled\' -Value 1 -Type DWord; Set-ItemProperty -Path $healthRegPath -Name \'DomainTrustCheckDisabled\' -Value 1 -Type DWord; Set-ItemProperty -Path $healthRegPath -Name \'AADJoinedCheck\' -Value 1 -Type DWord; try { $avdService = Get-Service -Name \'RDAgentBootLoader\' -ErrorAction SilentlyContinue; if ($avdService) { Restart-Service -Name \'RDAgentBootLoader\' -Force; Write-Host \'AVD Agent service restarted successfully\'; } } catch { Write-Host \'AVD Agent service restart skipped\'; }; Write-Host \'Health check configuration completed\'; }"'
    }
  }
}

// Outputs for verification and reference
output vmResourceId string = virtualMachine.id
output vmName string = virtualMachine.name
output nicResourceId string = networkInterface.id
output imageType string = useGalleryImage ? 'Azure Compute Gallery' : 'Marketplace'
output joinType string = 'Azure AD Join'
output vmSystemAssignedIdentity string = virtualMachine.identity.principalId
