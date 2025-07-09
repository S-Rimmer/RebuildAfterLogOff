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
   # Download and modify sample-templatespec.bicep
   # Update virtual network references, VM sizes, domain settings, etc.
   ```

2. **Create the Template Spec**:
   ```bash
   az ts create --resource-group "rg-templates" --name "avd-vm-rebuild" --location "East US 2"
   az ts version create --resource-group "rg-templates" --template-spec-name "avd-vm-rebuild" --version "1.0" --template-file "your-customized-template.bicep"
   ```

3. **Use in deployment**: During the automation deployment, select this Template Spec in the UI

### Template Spec Selection in UI:
- **Template Spec Resource**: Select your created Template Spec (e.g., "avd-vm-rebuild")
- **Version**: Specify the version (e.g., "1.0")

See `sample-templatespec.bicep` for a complete template example that you can customize for your environment.

Deployment:  

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FS-Rimmer%2FRebuildAfterLogoff%2Fmaster%2Fdeploy.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FS-Rimmer%2FRebuildAfterLogoff%2Fmaster%2FuiDefinition.json)

