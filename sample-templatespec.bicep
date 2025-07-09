// Sample Template Spec for AVD VM deployment supporting both Azure Compute Gallery and Marketplace images
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

// Variables
var nicName = '${vmName}-nic'
var computerName = vmName
var domainToJoin = ''  // Add your domain if domain joining
var ouPath = ''        // Add your OU path if domain joining

// Get existing virtual network and subnet
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnetName
  scope: resourceGroup(resourceGroupName)
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
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
  }
}

// Install AVD agent and register with host pool
resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: virtualMachine
  name: 'AVDAgent'
  location: location
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
        aadJoin: false
        UseAgentDownloadEndpoint: true
        aadJoinPreview: false
        mdmId: ''
        sessionHostConfigurationLastUpdateTime: ''
      }
    }
  }
}

// Output the VM resource ID
output vmResourceId string = virtualMachine.id
output vmName string = virtualMachine.name
