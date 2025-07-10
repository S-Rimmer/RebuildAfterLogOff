# What is this?

Per a request this code deploys an automation account and runbook to do the following:  
- Every 15 minutes check a specific host pool's VMs and if there are no current user sessions, remove the VM and re-add using a Template Spec

Scenario:  
Multisession (1 User Only) or Personal Host Pool in which data is sensitive and VM needs rebuild after use.

## Features
- **Azure Compute Gallery Support**: Fully supports Azure Compute Gallery images with automatic latest version detection
- **Marketplace Image Support**: Also supports traditional marketplace images (Publisher:Offer:Sku:Version format)
- **Flexible Image Selection**: UI allows selection between gallery and marketplace images during deployment
- **Smart Session Detection**: Monitors user sessions via Log Analytics and only rebuilds when safe to do so

PreReqs: 
- A template spec to be created to leverage for the host OS to be deployed (see `sample-templatespec.bicep` for reference)
- A Log Analytics Workspace
- Azure Compute Gallery with images (if using gallery images)
- Key Vault with VM admin credentials

## Automated Permissions

The deployment automatically configures all required permissions for the Automation Account's managed identity:

**✅ Subscription Level:**
- **Reader** - Access to read subscription resources and resource groups

**✅ AVD Resource Group:**
- **Contributor** - Full access to manage VMs, NICs, disks, and other AVD resources
- **Desktop Virtualization Virtual Machine Contributor** - Specialized AVD operations

**✅ Log Analytics Workspace:**
- **Log Analytics Reader** - Access to query session data and user activity logs

**✅ Key Vault:**
- **Key Vault Secrets User** - Access to retrieve VM admin credentials

> **Note:** No manual permission configuration is required after deployment. All role assignments are automatically created during the Bicep deployment.

The default name of the Automation account will start with AA-AVD unless changed in deployment.

## Image Support Details

### Azure Compute Gallery Images
- Format: `/subscriptions/{subscriptionId}/resourceGroups/{rgName}/providers/Microsoft.Compute/galleries/{galleryName}/images/{imageName}/versions/{version}`
- Automatic latest version detection if version not specified
- Preferred method for custom images and standardized deployments

### Marketplace Images  
- Format: `Publisher:Offer:Sku:Version` (e.g., `MicrosoftWindowsDesktop:Windows-10:20h2-evd:latest`)
- Traditional Azure marketplace image support
- Useful for standard Microsoft-provided images

## Template Spec Requirements

**You must create a Template Spec BEFORE deploying this automation solution.** The Template Spec defines how new VMs are deployed to replace the rebuilt session hosts.

### How to Choose/Create Your Template Spec:

1. **Use the provided sample**: Start with `sample-templatespec.bicep` in this repository
2. **Customize for your environment**: Modify networking, VM sizing, and AVD configuration
3. **Deploy as Template Spec**: Create the Template Spec in Azure before running this automation

### Required Template Spec Parameters:
Your Template Spec must support the following parameters:
- `useGalleryImage` (bool): Determines image type
- `imageId` (string): Gallery image resource ID (when useGalleryImage=true)
- `imagePublisher`, `imageOffer`, `imageSku`, `imageVersion` (strings): Marketplace image details (when useGalleryImage=false)
- Standard VM parameters: `vmName`, `vmSize`, `adminUsername`, `adminPassword`, etc.

### Template Spec Deployment Steps:

1. **Customize the sample template**:
   ```bash
   # Download the sample-templatespec.bicep from this repository
   # Modify these key areas for your environment:
   ```
   
   **Required Customizations in `sample-templatespec.bicep`:**
   ```bicep
   // Update virtual network reference (lines 53-56)
   resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
     name: vnetName
     scope: resourceGroup('YOUR-VNET-RESOURCE-GROUP-NAME') // Update this!
   }
   
   // Optional: Add domain join settings (lines 49-50)
   var domainToJoin = 'yourdomain.com'  // Add your domain
   var ouPath = 'OU=AVD,DC=yourdomain,DC=com'  // Add your OU path
   ```

2. **Deploy the Template Spec to Azure**:

   **Option A - Azure CLI:**
   ```bash
   # Create the Template Spec container
   az ts create \
     --resource-group "rg-templatespecs" \
     --name "avd-vm-rebuild" \
     --location "East US 2" \
     --description "Template for rebuilding AVD session host VMs"

   # Deploy your customized template as version 1.0
   az ts version create \
     --resource-group "rg-templatespecs" \
     --template-spec-name "avd-vm-rebuild" \
     --version "1.0" \
     --template-file "sample-templatespec.bicep" \
     --version-description "Initial version with gallery image support"
   ```

   **Option B - Azure PowerShell:**
   ```powershell
   # Create the Template Spec container
   New-AzTemplateSpec `
     -ResourceGroupName "rg-templatespecs" `
     -Name "avd-vm-rebuild" `
     -Location "East US 2" `
     -Description "Template for rebuilding AVD session host VMs"

   # Deploy your customized template as version 1.0
   New-AzTemplateSpecVersion `
     -ResourceGroupName "rg-templatespecs" `
     -TemplateSpecName "avd-vm-rebuild" `
     -VersionName "1.0" `
     -TemplateFile "sample-templatespec.bicep" `
     -VersionDescription "Initial version with gallery image support"
   ```

   **Option C - Azure Portal:**
   1. Navigate to **Template specs** in the Azure Portal
   2. Click **Create template spec**
   3. Enter name: `avd-vm-rebuild`
   4. Select resource group and location
   5. Click **Next: Edit template**
   6. **Important**: Use the JSON template (`sample-templatespec.json`) not the Bicep file
   7. Copy/paste the content from `sample-templatespec.json`
   8. Click **Review + create**

3. **Test the Template Spec** (Optional but recommended):
   ```bash
   # Get a host pool registration token first
   $token = (New-AzWvdRegistrationInfo -ResourceGroupName "rg-avd" -HostPoolName "hp-test" -ExpirationTime (Get-Date).AddHours(2)).Token

   # Test deployment with gallery image
   az deployment group create \
     --resource-group "rg-avd-test" \
     --template-spec "/subscriptions/YOUR-SUB-ID/resourceGroups/rg-templatespecs/providers/Microsoft.Resources/templateSpecs/avd-vm-rebuild/versions/1.0" \
     --parameters \
       vmName="test-vm-01" \
       vmSize="Standard_D2s_v3" \
       adminUsername="azureuser" \
       adminPassword="YourSecurePassword123!" \
       hostPoolName="hp-test" \
       resourceGroupName="rg-avd-test" \
       location="East US 2" \
       vnetName="vnet-avd" \
       subnetName="subnet-avd" \
       registrationInfoToken="$token" \
       useGalleryImage=true \
       imageId="/subscriptions/YOUR-SUB-ID/resourceGroups/rg-images/providers/Microsoft.Compute/galleries/gal_avd/images/win10-21h2/versions/1.0.0"
   ```

4. **Use in automation deployment**: 
   - **Template Spec**: Select your created Template Spec (e.g., `avd-vm-rebuild`)
   - **Template Spec Version**: Enter the version (e.g., `1.0`)
   - **Resource Group**: Where you created the Template Spec (e.g., `rg-templatespecs`)

### Template Spec Selection in UI:
- **Template Spec Resource**: Select your created Template Spec (e.g., "avd-vm-rebuild")
- **Version**: Specify the version (e.g., "1.0")

See `sample-templatespec.bicep` for a complete template example that you can customize for your environment.

## Deployment

**⚠️ Important**: You must create a Template Spec BEFORE clicking the deployment button below. See the [Template Spec deployment instructions](#template-spec-deployment-steps) or [TEMPLATE_SPEC_GUIDE.md](TEMPLATE_SPEC_GUIDE.md) for detailed steps.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FS-Rimmer%2FRebuildAfterLogoff%2Fmaster%2Fdeploy.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FS-Rimmer%2FRebuildAfterLogoff%2Fmaster%2FuiDefinition.json)

## Validation and Testing

### Pre-Deployment Validation:
Before deploying the automation, validate your Template Spec works correctly:

```bash
# Test Template Spec deployment manually
az deployment group create \
  --resource-group "rg-avd-test" \
  --template-spec "/subscriptions/YOUR-SUB-ID/resourceGroups/rg-templatespecs/providers/Microsoft.Resources/templateSpecs/avd-vm-rebuild/versions/1.0" \
  --parameters vmName="test-vm-01" vmSize="Standard_D2s_v3" adminUsername="azureuser" adminPassword="YourPassword123!"
```

### Post-Deployment Testing:
1. **Check Automation Account**: Verify the runbook imports successfully
2. **Review Permissions**: Confirm all role assignments are created (see Outputs section)
3. **Test Runbook**: Run the PowerShell runbook manually to verify it executes without errors
4. **Monitor Schedule**: Ensure the 15-minute schedule is active

### Common Issues:
- **MSI Subscription Access Error**: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed resolution steps
- **Template Spec Not Found**: Verify Template Spec was created successfully and version exists
- **Role Assignment Delays**: Allow 10-15 minutes after deployment for permissions to propagate

### Troubleshooting:
- **Runbook Errors**: Check the Automation Account logs for detailed error messages
- **Permission Issues**: Review the role assignments using the provided output values
- **Template Spec Failures**: Validate Template Spec parameters and test manual deployment

## Quick Reference

### Essential Files:
- **`deploy.bicep`** - Main automation deployment template
- **`sample-templatespec.bicep`** - Sample Template Spec for VM deployment
- **`AVD-CheckAndRebuildAtLogoff.ps1`** - PowerShell runbook script
- **`TEMPLATE_SPEC_GUIDE.md`** - Detailed Template Spec creation guide
- **`PERMISSIONS.md`** - Complete permissions documentation

### Template Spec Quick Setup:
```bash
# 1. Customize sample-templatespec.bicep for your environment
# 2. Create Template Spec
az ts create --resource-group "rg-templatespecs" --name "avd-vm-rebuild" --location "East US 2"
az ts version create --resource-group "rg-templatespecs" --template-spec-name "avd-vm-rebuild" --version "1.0" --template-file "sample-templatespec.bicep"

# 3. Use in automation deployment:
# - Template Spec Resource Group: rg-templatespecs
# - Template Spec Name: avd-vm-rebuild  
# - Template Spec Version: 1.0
```

### Support for Multiple Image Types:
| Image Type | Format | Example |
|------------|--------|---------|
| **Azure Compute Gallery** | `/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/galleries/{gallery}/images/{image}/versions/{version}` | `/subscriptions/.../galleries/myGallery/images/win10-21h2/versions/latest` |
| **Marketplace** | `Publisher:Offer:Sku:Version` | `MicrosoftWindowsDesktop:Windows-10:21h2-evd:latest` |

---

*For detailed deployment instructions, see [TEMPLATE_SPEC_GUIDE.md](TEMPLATE_SPEC_GUIDE.md)*
*For permissions details, see [PERMISSIONS.md](PERMISSIONS.md)*

### Template Spec Parameter Examples:

**For Azure AD Join (No Domain):**
```bash
# When creating Template Spec - all domain parameters can be omitted or left empty
az ts version create \
  --resource-group "rg-templatespecs" \
  --template-spec-name "avd-vm-rebuild" \
  --version "1.0" \
  --template-file "sample-templatespec.bicep"

# When deploying via Template Spec - domain parameters are optional
az deployment group create \
  --template-spec "/subscriptions/.../templateSpecs/avd-vm-rebuild/versions/1.0" \
  --parameters \
    vmName="avd-vm-01" \
    useGalleryImage=true \
    imageId="/subscriptions/.../galleries/myGallery/images/win10/versions/latest" \
    # domainToJoin="" (empty = Azure AD join)
    # domainUsername="" (not needed)
    # domainPassword="" (not needed)
```

**For Domain Join:**
```bash
# When deploying via Template Spec - specify domain parameters
az deployment group create \
  --template-spec "/subscriptions/.../templateSpecs/avd-vm-rebuild/versions/1.0" \
  --parameters \
    vmName="avd-vm-01" \
    domainToJoin="contoso.com" \
    domainUsername="admin@contoso.com" \
    domainPassword="YourDomainPassword123!" \
    ouPath="OU=AVD,DC=contoso,DC=com"
```

## Template Spec File Formats

This repository provides the sample template in two formats:

### **For Azure CLI & PowerShell:**
- **File**: `sample-templatespec.bicep`
- **Format**: Bicep (recommended for CLI/PowerShell deployment)
- **Benefits**: Cleaner syntax, easier to read and modify

### **For Azure Portal:**
- **File**: `sample-templatespec.json` 
- **Format**: ARM JSON template with required schema
- **Benefits**: Works directly in the Portal Template Spec editor

> **Note**: Both files deploy identical resources - choose the format based on your deployment method.

