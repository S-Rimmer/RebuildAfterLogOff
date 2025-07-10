/*
Sample Template Spec for AVD VM deployment supporting both Azure Compute Gallery and Marketplace images

DEPLOYMENT METHODS:
- Azure CLI/PowerShell: Use this Bicep file
- Azure Portal: Use sample-templatespec.json instead (ARM JSON format required)

BEFORE DEPLOYING AS TEMPLATE SPEC:
1. Update the VNet resource group name on line 80 (scope: resourceGroup('rg-network'))
2. Configure domain join parameters if needed (all optional for Azure AD join)
3. Test the template with your parameters before creating the Template Spec
4. Deploy as Template Spec using Azure CLI, PowerShell, or Portal (see README.md)

This template automatically handles:
✅ Azure Compute Gallery images with imageId parameter
✅ Marketplace images with publisher/offer/sku/version parameters  
✅ Conditional domain join (Azure AD join if no domain specified)
✅ Proper resource cleanup with deleteOption settings
✅ AVD agent installation and host pool registration
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

// Variables
var nicName = '${vmName}-nic'
var computerName = vmName

// Get existing virtual network and subnet
// ⚠️ IMPORTANT: Update the resourceGroupName below to match your VNet's resource group
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnetName
  scope: resourceGroup('rg-network') // TODO: Change 'rg-network' to your VNet's resource group name
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
        // Azure Compute Gallery image reference
        id: imageId
      } : {
        // Marketplace image reference
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
resource aadJoinExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = if (empty(domainToJoin)) {
  parent: virtualMachine
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      mdmId: ''
    }
  }
}

// Install AVD agent and register with host pool
resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: virtualMachine
  name: 'AVDAgent'
  location: location
  dependsOn: [
    domainJoinExtension // Ensure domain join completes first (if enabled)
    aadJoinExtension    // Ensure Azure AD join completes first (if enabled)
  ]
  properties: {
    publisher: 'Microsoft.PowerShell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_3-10-2021.zip'
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostPoolName
        registrationInfoToken: registrationInfoToken
        aadJoin: empty(domainToJoin) ? true : false
        UseAgentDownloadEndpoint: true
        aadJoinPreview: false
        mdmId: ''
        sessionHostConfigurationLastUpdateTime: ''
      }
    }
  }
}

// Outputs for verification and reference
output vmResourceId string = virtualMachine.id
output vmName string = virtualMachine.name
output nicResourceId string = networkInterface.id
output imageType string = useGalleryImage ? 'Azure Compute Gallery' : 'Marketplace'
output joinType string = empty(domainToJoin) ? 'Azure AD Join' : 'Domain Join'
