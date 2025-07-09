# Template Spec Creation Guide

This guide walks you through creating the required Template Spec for the AVD VM rebuild automation.

## Overview

The Template Spec is a reusable ARM/Bicep template that defines how to deploy a new AVD session host VM. The automation script uses this Template Spec to recreate VMs after they've been removed.

## Step 1: Customize the Sample Template

1. **Start with the provided sample**:
   - Use `sample-templatespec.bicep` as your starting point
   - This template already supports both gallery and marketplace images

2. **Customize for your environment**:
   ```bicep
   // Update these values for your environment
   var domainToJoin = 'yourdomain.com'  // Add your domain if domain joining
   var ouPath = 'OU=AVD,DC=yourdomain,DC=com'  // Add your OU path
   
   // Update virtual network reference
   resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
     name: vnetName
     scope: resourceGroup('your-vnet-resource-group')  // Update if different RG
   }
   ```

3. **Key areas to customize**:
   - **Virtual Network**: Update the VNET name and resource group
   - **Domain Join**: Add domain joining logic if needed
   - **VM Extensions**: Add any required extensions (antivirus, monitoring, etc.)
   - **Storage**: Modify disk configuration if needed
   - **Networking**: Update subnet references

## Step 2: Create the Template Spec

### Using Azure CLI:

```bash
# Create the Template Spec container
az ts create \
  --resource-group "rg-templatespecs" \
  --name "avd-vm-rebuild" \
  --location "East US 2" \
  --description "Template for rebuilding AVD session host VMs"

# Upload your customized template as version 1.0
az ts version create \
  --resource-group "rg-templatespecs" \
  --template-spec-name "avd-vm-rebuild" \
  --version "1.0" \
  --template-file "your-customized-template.bicep" \
  --version-description "Initial version with gallery image support"
```

### Using Azure PowerShell:

```powershell
# Create the Template Spec container
New-AzTemplateSpec `
  -ResourceGroupName "rg-templatespecs" `
  -Name "avd-vm-rebuild" `
  -Location "East US 2" `
  -Description "Template for rebuilding AVD session host VMs"

# Upload your customized template as version 1.0
New-AzTemplateSpecVersion `
  -ResourceGroupName "rg-templatespecs" `
  -TemplateSpecName "avd-vm-rebuild" `
  -VersionName "1.0" `
  -TemplateFile "your-customized-template.bicep" `
  -VersionDescription "Initial version with gallery image support"
```

### Using Azure Portal:

1. Navigate to **Template specs** in the Azure Portal
2. Click **Create template spec**
3. Fill in:
   - **Name**: `avd-vm-rebuild`
   - **Resource Group**: Choose or create a resource group
   - **Location**: Same as your other resources
4. Click **Next: Edit template**
5. Paste your customized Bicep template
6. Click **Review + create**

## Step 3: Test the Template Spec

Before using with the automation, test your Template Spec manually:

```bash
# Test deployment
az deployment group create \
  --resource-group "rg-avd-test" \
  --template-spec "/subscriptions/YOUR-SUB-ID/resourceGroups/rg-templatespecs/providers/Microsoft.Resources/templateSpecs/avd-vm-rebuild/versions/1.0" \
  --parameters vmName="test-vm-01" vmSize="Standard_D2s_v3" adminUsername="azureuser" adminPassword="YourPassword123!" hostPoolName="hp-test" resourceGroupName="rg-avd-test" location="East US 2" vnetName="vnet-avd" subnetName="subnet-avd" registrationInfoToken="YOUR-TOKEN" useGalleryImage=true imageId="/subscriptions/YOUR-SUB-ID/resourceGroups/rg-images/providers/Microsoft.Compute/galleries/gal_avd/images/win10-21h2/versions/1.0.0"
```

## Step 4: Use in Automation Deployment

When deploying the automation solution:

1. **Template Spec Resource**: Select your created Template Spec
   - Name: `avd-vm-rebuild`
   - Resource Group: `rg-templatespecs`

2. **Template Spec Version**: 
   - Version: `1.0`

## Template Spec Parameter Configuration

### For Azure AD Join (No Domain Join)
When you don't need domain join, simply omit or leave empty the domain-related parameters:

```bash
# Template Spec creation - no special configuration needed
az ts version create \
  --resource-group "rg-templatespecs" \
  --template-spec-name "avd-vm-rebuild" \
  --version "1.0" \
  --template-file "sample-templatespec.bicep"

# Test deployment without domain join
az deployment group create \
  --resource-group "rg-avd-test" \
  --template-spec "/subscriptions/YOUR-SUB-ID/resourceGroups/rg-templatespecs/providers/Microsoft.Resources/templateSpecs/avd-vm-rebuild/versions/1.0" \
  --parameters \
    vmName="test-vm-01" \
    vmSize="Standard_D2s_v3" \
    adminUsername="azureuser" \
    adminPassword="YourPassword123!" \
    hostPoolName="hp-test" \
    resourceGroupName="rg-avd-test" \
    location="East US 2" \
    vnetName="vnet-avd" \
    subnetName="subnet-avd" \
    registrationInfoToken="YOUR-TOKEN" \
    useGalleryImage=true \
    imageId="/subscriptions/YOUR-SUB-ID/resourceGroups/rg-images/providers/Microsoft.Compute/galleries/gal_avd/images/win10/versions/latest"
    # Note: domainToJoin, domainUsername, domainPassword, and ouPath are optional and default to empty
```

### For Domain Join
When you need domain join, specify the domain parameters:

```bash
# Test deployment with domain join
az deployment group create \
  --resource-group "rg-avd-test" \
  --template-spec "/subscriptions/YOUR-SUB-ID/resourceGroups/rg-templatespecs/providers/Microsoft.Resources/templateSpecs/avd-vm-rebuild/versions/1.0" \
  --parameters \
    vmName="test-vm-01" \
    vmSize="Standard_D2s_v3" \
    adminUsername="azureuser" \
    adminPassword="YourPassword123!" \
    hostPoolName="hp-test" \
    resourceGroupName="rg-avd-test" \
    location="East US 2" \
    vnetName="vnet-avd" \
    subnetName="subnet-avd" \
    registrationInfoToken="YOUR-TOKEN" \
    useGalleryImage=true \
    imageId="/subscriptions/YOUR-SUB-ID/.../images/win10/versions/latest" \
    domainToJoin="contoso.com" \
    domainUsername="admin@contoso.com" \
    domainPassword="YourDomainPassword123!" \
    ouPath="OU=AVD,DC=contoso,DC=com"
```

## Common Template Spec Patterns

### Basic AVD VM (No Domain Join)
```bicep
// VM with AVD agent only - suitable for Azure AD joined VMs
resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: virtualMachine
  name: 'AVDAgent'
  // ...AVD agent configuration
}
```

### Domain-Joined AVD VM
```bicep
// Add domain join extension before AVD agent
resource domainJoinExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: virtualMachine
  name: 'DomainJoin'
  // ...domain join configuration
}

resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: virtualMachine
  name: 'AVDAgent'
  // ...AVD agent configuration
  dependsOn: [domainJoinExtension]
}
```

### With Additional Extensions
```bicep
// Add monitoring, antivirus, or other required extensions
resource monitoringExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: virtualMachine
  name: 'AzureMonitorWindowsAgent'
  // ...monitoring configuration
}
```

## Troubleshooting Template Specs

### Common Issues:

1. **"Template Spec not found"**
   - Verify the Template Spec name and resource group
   - Check permissions to the Template Spec resource group

2. **"Parameter validation failed"**
   - Ensure your Template Spec accepts all required parameters
   - Check parameter types match the expected values

3. **"Virtual network not found"**
   - Update VNET references in your template
   - Ensure correct resource group scoping

### Validation Commands:

```bash
# List your Template Specs
az ts list --resource-group "rg-templatespecs"

# Show Template Spec details
az ts show --resource-group "rg-templatespecs" --name "avd-vm-rebuild"

# List versions
az ts version list --resource-group "rg-templatespecs" --template-spec-name "avd-vm-rebuild"
```

## Best Practices

1. **Version Control**: Use semantic versioning (1.0, 1.1, 2.0) for your Template Spec versions
2. **Testing**: Always test Template Specs manually before using in automation
3. **Documentation**: Add descriptions to your Template Spec and versions
4. **Security**: Store sensitive parameters in Key Vault, not in the template
5. **Modularity**: Keep templates focused and reusable
6. **Validation**: Include parameter validation in your templates

## Example Directory Structure

```
your-project/
├── templates/
│   ├── avd-vm-base.bicep              # Your customized template
│   ├── avd-vm-domain-joined.bicep     # Domain-joined variant
│   └── deploy-templatespec.bicep      # Script to deploy Template Spec
├── parameters/
│   └── avd-vm-parameters.json         # Test parameters
└── scripts/
    └── deploy-templatespec.ps1        # PowerShell deployment script
```

This structure helps organize your Template Spec development and deployment process.
