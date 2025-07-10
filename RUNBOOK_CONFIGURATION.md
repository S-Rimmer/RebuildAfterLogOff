# Azure Automation Runbook Configuration Guide

## Overview
This guide explains how to configure the Azure Automation runbook parameters to resolve Azure AD Join errors and other deployment issues.

## Runbook Parameters Configuration

### Required Parameters
These parameters must be configured in your Azure Automation runbook:

| Parameter | Type | Description | Example Value |
|-----------|------|-------------|---------------|
| `CloudEnvironment` | String | Azure cloud environment | `AzureCloud` |
| `HostPoolName` | String | Name of your AVD host pool | `hp-avd-personal` |
| `avdRG` | String | Resource group containing AVD resources | `rg-avd-resources` |
| `SubscriptionId` | String | Azure subscription ID | `12345678-1234-1234-1234-123456789012` |
| `TemplateSpecName` | String | Name of the Template Spec | `AVD-VM-Template` |
| `TemplateSpecVersion` | String | Version of the Template Spec | `1.0` |
| `TemplateSpecRG` | String | Resource group containing Template Spec | `rg-templates` |
| `KeyVaultName` | String | Name of Key Vault with secrets | `kv-avd-secrets` |
| `KeyVaultVMAdmin` | String | Key Vault secret name for VM admin password | `VMAdminPassword` |
| `WorkspaceId` | String | Log Analytics workspace ID | `12345678-1234-1234-1234-123456789012` |
| `IfNotUsedInHrs` | String | Hours of inactivity before rebuild | `24` |
| `imageId` | String | VM image identifier | See image configuration below |

### Optional Parameters
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enableAzureADJoin` | Boolean | `false` | Enable Azure AD Join extension |

## Image Configuration

### Option 1: Azure Compute Gallery Image
```
/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Compute/galleries/{gallery-name}/images/{image-name}/versions/{version}
```

### Option 2: Marketplace Image
```
Publisher:Offer:Sku:Version
```
Example: `MicrosoftWindowsDesktop:Windows-11:win11-22h2-avd:latest`

## Azure AD Join Configuration

### When to Disable Azure AD Join (`enableAzureADJoin = false`)
- **Network connectivity issues** to Azure AD endpoints
- **DNS resolution problems** in your virtual network
- **Firewall/NSG blocking** required Azure AD URLs
- **Regional connectivity issues** to Azure AD services
- **Not required** for your AVD deployment

### When to Enable Azure AD Join (`enableAzureADJoin = true`)
- VMs need to be Azure AD joined (not domain joined)
- Network connectivity to Azure AD is confirmed working
- All required URLs are accessible from the subnet

## Network Requirements for Azure AD Join

If you enable Azure AD Join, ensure these requirements are met:

### Required Outbound Connectivity (HTTPS/443)
- `login.microsoftonline.com`
- `device.login.microsoftonline.com`
- `pas.windows.net`
- `management.azure.com`
- `enterpriseregistration.windows.net`

### DNS Configuration
- VMs must resolve Azure AD domains
- Configure Azure DNS or custom DNS with external resolution

## Runbook Configuration Steps

### 1. Azure Portal Configuration
1. Navigate to your Automation Account
2. Go to **Runbooks** → Select your runbook
3. Click **Parameters**
4. Set parameter values as shown above

### 2. PowerShell Configuration
```powershell
# Example: Start runbook with parameters
Start-AzAutomationRunbook -AutomationAccountName "aa-avd-automation" `
    -ResourceGroupName "rg-automation" `
    -Name "AVD-CheckAndRebuildAtLogoff" `
    -Parameters @{
        CloudEnvironment = "AzureCloud"
        HostPoolName = "hp-avd-personal"
        avdRG = "rg-avd-resources"
        SubscriptionId = "12345678-1234-1234-1234-123456789012"
        TemplateSpecName = "AVD-VM-Template"
        TemplateSpecVersion = "1.0"
        TemplateSpecRG = "rg-templates"
        KeyVaultName = "kv-avd-secrets"
        KeyVaultVMAdmin = "VMAdminPassword"
        WorkspaceId = "12345678-1234-1234-1234-123456789012"
        IfNotUsedInHrs = "24"
        imageId = "MicrosoftWindowsDesktop:Windows-11:win11-22h2-avd:latest"
        enableAzureADJoin = $false  # Disable Azure AD Join to avoid connectivity errors
    }
```

### 3. Schedule Configuration
If using a schedule:
1. Go to **Schedules** in your Automation Account
2. Create or edit your schedule
3. Link to the runbook with the parameters above

## Troubleshooting

### Azure AD Join Errors (0x801c002d)
1. **Set `enableAzureADJoin = false`** to disable the problematic extension
2. Test VM deployment without Azure AD Join
3. Verify network connectivity from subnet to Azure AD endpoints
4. Re-enable only after resolving network issues

### Permission Errors
1. Verify the managed identity has required role assignments
2. Check that role assignments have propagated (can take up to 5 minutes)
3. See `PERMISSIONS.md` for detailed role assignment requirements

### Template Spec Errors
1. Verify Template Spec exists and version is correct
2. Check Template Spec resource group permissions
3. See `TEMPLATE_SPEC_GUIDE.md` for Template Spec configuration

### Network Errors
1. Verify VNet and subnet names are correct
2. Check NSG rules allow required connectivity
3. See `FIX_NETWORK_PERMISSIONS.md` for network troubleshooting

## Testing Configuration

### 1. Test Run
Start with a test run using:
```
enableAzureADJoin = false
```

### 2. Monitor Deployment
- Check runbook output logs
- Monitor ARM deployment progress
- Verify session host registration in AVD

### 3. Validate Results
- Confirm VM is created and running
- Check session host status in AVD portal
- Test user logon to verify functionality

## Best Practices

1. **Start with `enableAzureADJoin = false`** for initial testing
2. **Test connectivity** before enabling Azure AD Join
3. **Monitor runbook logs** for detailed error information
4. **Keep Template Spec updated** with latest configurations
5. **Document parameter changes** for your environment

## Related Files
- `AVD-CheckAndRebuildAtLogoff.ps1` - Main runbook script
- `sample-templatespec.bicep` - Template Spec definition
- `FIX_AZURE_AD_JOIN_ERROR.md` - Specific Azure AD Join troubleshooting
- `PERMISSIONS.md` - Role assignment requirements
