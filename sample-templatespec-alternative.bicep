/*
Alternative Template Spec for AVD VM deployment - Custom Script Extension Approach
This version uses CustomScriptExtension instead of DSC to avoid domain health check issues
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

@description('Domain to join (optional - leave empty for Azure AD join only)')
param domainToJoin string = ''

@description('OU path for domain join (optional - leave empty for default OU)')
param ouPath string = ''

@description('Domain username for joining (required only if domainToJoin is specified)')
param domainUsername string = ''

@description('Domain password for joining (required only if domainToJoin is specified)')
@secure()
param domainPassword string = ''

@description('Security type for the virtual machine (Standard or TrustedLaunch)')
@allowed(['Standard', 'TrustedLaunch'])
param securityType string = 'TrustedLaunch'

@description('Enable Secure Boot (requires TrustedLaunch security type)')
param enableSecureBoot bool = true

@description('Enable vTPM (requires TrustedLaunch security type)')
param enableVtpm bool = true

@description('Enable Azure AD join extension (set to false if experiencing AAD join issues)')
param enableAzureADJoin bool = true

// Variables
var nicName = '${vmName}-nic'
var computerName = vmName

// Get existing virtual network and subnet
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnetName
  scope: resourceGroup('EST2_SharedResources')
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
        deleteOption: 'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
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

// Optional: Domain join extension (only deployed if domainToJoin is configured)
resource domainJoinExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = if (!empty(domainToJoin)) {
  parent: virtualMachine
  name: 'DomainJoin'
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      name: domainToJoin
      ouPath: !empty(ouPath) ? ouPath : null
      user: domainUsername
      restart: true
      options: 3
    }
    protectedSettings: {
      password: domainPassword
    }
  }
}

// Azure AD Join extension (only deployed if NOT domain joining)
resource aadJoinExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = if (empty(domainToJoin) && enableAzureADJoin) {
  parent: virtualMachine
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}

// Install AVD agent using CustomScriptExtension (alternative to DSC)
resource avdAgentInstallation 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: virtualMachine
  name: 'AVDAgentInstall'
  location: location
  dependsOn: [
    domainJoinExtension
    aadJoinExtension
  ]
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $isAADJoined = ${empty(domainToJoin) && enableAzureADJoin ? 'true' : 'false'}; $hostPoolName = \'${hostPoolName}\'; $registrationToken = \'${registrationInfoToken}\'; Invoke-WebRequest -Uri \'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv\' -OutFile \'C:\\AVDAgent.msi\' -UseBasicParsing; Start-Process -FilePath \'msiexec.exe\' -ArgumentList \'/i C:\\AVDAgent.msi /quiet /qn /norestart /passive\' -Wait; Invoke-WebRequest -Uri \'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH\' -OutFile \'C:\\AVDBootLoader.msi\' -UseBasicParsing; Start-Process -FilePath \'msiexec.exe\' -ArgumentList \'/i C:\\AVDBootLoader.msi /quiet /qn /norestart /passive\' -Wait; $regKey = \'HKLM:\\SOFTWARE\\Microsoft\\RDInfraAgent\'; if(!(Test-Path $regKey)) { New-Item -Path $regKey -Force }; Set-ItemProperty -Path $regKey -Name \'RegistrationToken\' -Value $registrationToken; Set-ItemProperty -Path $regKey -Name \'IsRegistered\' -Value 0; if($isAADJoined -eq \'true\') { Set-ItemProperty -Path $regKey -Name \'UseAADJoin\' -Value 1 }; Start-Process -FilePath \'C:\\Program Files\\Microsoft RDInfra\\AgentInstall.exe\' -ArgumentList \'/S\' -Wait; Restart-Service -Name \'RDAgentBootLoader\' -Force; }"'
    }
  }
}

// Outputs
output vmResourceId string = virtualMachine.id
output vmName string = virtualMachine.name
output nicResourceId string = networkInterface.id
output imageType string = useGalleryImage ? 'Azure Compute Gallery' : 'Marketplace'
output joinType string = empty(domainToJoin) ? 'Azure AD Join' : 'Domain Join'
