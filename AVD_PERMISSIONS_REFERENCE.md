# Required Permissions for AVD Session Host Management with Azure AD

## Microsoft Graph API Permissions (Application Permissions)
These must be granted to the Automation Account's **managed identity**:

### ✅ Essential Permissions:
- **`Device.ReadWrite.All`** 
  - Purpose: Delete Azure AD device registrations to prevent hostname conflicts
  - Why needed: When a VM is rebuilt, the old device registration must be removed

- **`Directory.ReadWrite.All`**
  - Purpose: Manage Azure AD objects and device registrations
  - Why needed: Comprehensive access to Azure AD for device management

### 🔄 Optional (if using Intune/MDM):
- **`DeviceManagementManagedDevices.ReadWrite.All`**
  - Purpose: Manage Intune-enrolled devices
  - Why needed: If using MDM enrollment with Azure AD join

## Azure RBAC Permissions
These are assigned at the **resource/resource group level**:

### 🖥️ VM Management:
- **`Virtual Machine Contributor`** (on AVD resource group)
  - Create, delete, start, stop VMs
  
- **`Network Contributor`** (on AVD resource group)
  - Manage network interfaces and IP configurations

- **`Storage Account Contributor`** (on AVD resource group)
  - Manage VM disks and storage accounts

### 🖼️ AVD Specific:
- **`Desktop Virtualization Contributor`** (on AVD resource group)
  - Manage host pools, session hosts, registration tokens

### 📋 Template and Secrets:
- **`Template Spec Reader`** (on template spec resource group)
  - Read and deploy Bicep template specs

- **`Key Vault Secrets User`** (on specific Key Vault)
  - Read admin passwords from Key Vault

- **`Log Analytics Reader`** (on Log Analytics workspace)
  - Query session data for rebuild decisions

## How Your Script Uses These Permissions:

### During VM Removal:
1. **`Virtual Machine Contributor`** - Stop and delete VM
2. **`Network Contributor`** - Delete network interface
3. **`Storage Account Contributor`** - Delete OS disk
4. **`Desktop Virtualization Contributor`** - Remove session host from pool
5. **`Device.ReadWrite.All`** - Delete Azure AD device registration

### During VM Creation:
1. **`Template Spec Reader`** - Read template spec for deployment
2. **`Key Vault Secrets User`** - Get admin password
3. **`Virtual Machine Contributor`** - Create new VM
4. **`Network Contributor`** - Create network interface
5. **`Desktop Virtualization Contributor`** - Register with host pool

### During Monitoring:
1. **`Log Analytics Reader`** - Query session history
2. **`Desktop Virtualization Contributor`** - Check session host status

## Grant Permissions Command:
```powershell
.\Grant-Complete-AVD-Permissions.ps1 `
    -AutomationAccountName "YourAutomationAccount" `
    -ResourceGroupName "YourResourceGroup" `
    -SubscriptionId "YourSubscriptionId" `
    -AVDResourceGroupName "YourAVDResourceGroup" `
    -KeyVaultName "YourKeyVault"
```

## Verification Commands:
```powershell
# Check Graph permissions
Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentity.Id

# Check RBAC permissions  
Get-AzRoleAssignment -ObjectId $managedIdentity.Id
```

## Common Issues:
- **Insufficient permissions**: User running the script needs Global Administrator
- **Permission propagation**: Allow 5-15 minutes for permissions to take effect
- **Missing managed identity**: Ensure system-assigned identity is enabled on Automation Account
- **Wrong scope**: Ensure permissions are granted on correct resource groups/resources
