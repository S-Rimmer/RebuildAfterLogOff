# Permissions and Role Assignments

This document outlines the permissions automatically configured by the deployment and any additional considerations.

## Automated Role Assignments

The Bicep deployment automatically creates the following role assignments for the Automation Account's system-assigned managed identity:

### 1. Subscription Level Permissions

| Role | Scope | Purpose | Role Definition ID |
|------|-------|---------|-------------------|
| **Reader** | Subscription | Read access to all resources for discovery and validation | `acdd72a7-3385-48ef-bd42-f606fba81ae7` |

**Permissions Include:**
- List and read all resource groups
- Discover AVD host pools and session hosts
- Read Template Spec definitions
- Access to Azure Compute Gallery resources

### 2. AVD Resource Group Permissions

| Role | Scope | Purpose | Role Definition ID |
|------|-------|---------|-------------------|
| **Contributor** | AVD Resource Group | Full management access to AVD resources | `b24988ac-6180-42a0-ab88-20f7382dd24c` |
| **Desktop Virtualization Virtual Machine Contributor** | AVD Resource Group | Specialized AVD operations | `a959dbd1-f747-45e3-8ba6-dd80f235f97c` |

**Operations Enabled:**
- Create, modify, and delete virtual machines
- Manage network interfaces and disks
- Add/remove session hosts from host pools
- Generate and manage host pool registration tokens
- Deploy VMs from Template Specs
- Access virtual networks and subnets

### 3. Log Analytics Workspace Permissions

| Role | Scope | Purpose | Role Definition ID |
|------|-------|---------|-------------------|
| **Log Analytics Reader** | Log Analytics Workspace Resource Group | Query session and connection data | `73c42c96-874c-492b-b04d-ab87d138a893` |

**Queries Supported:**
- WVDConnections table for user session history
- Session state and timing analysis
- User activity monitoring

### 4. Key Vault Permissions

| Role | Scope | Purpose | Role Definition ID |
|------|-------|---------|-------------------|
| **Key Vault Secrets User** | Automation Account Resource Group | Retrieve VM administrator credentials | `4633458b-17de-408a-b874-0445c86b69e6` |

**Access Provided:**
- Read secrets containing VM admin passwords
- Support for both RBAC and Access Policy models

## Deployment Requirements

### Deploying User Permissions

The user or service principal deploying this template must have:

1. **Owner** or **User Access Administrator** role at the subscription level
   - Required to create role assignments
2. **Contributor** access to target resource groups
   - Required to deploy resources

### Key Vault Access Models

#### RBAC Model (Recommended)
- Uses the **Key Vault Secrets User** role assignment (automatically configured)
- No additional access policies needed

#### Access Policy Model (Legacy)
If your Key Vault uses access policies instead of RBAC:
1. Add an access policy for the Automation Account's managed identity
2. Grant **Get** permission for secrets
3. Use the system-assigned managed identity principal ID from the deployment output

## Security Best Practices

### Principle of Least Privilege
- The deployment follows least privilege principles
- Each role assignment is scoped to the minimum required level
- Permissions are specific to the operational requirements

### Managed Identity Benefits
- No credential management required
- Automatic credential rotation
- Azure AD integration for audit and compliance

### Monitoring and Auditing
- All operations are logged in Azure Activity Log
- Role assignments are tracked in Azure AD audit logs
- Automation Account job logs provide detailed operation history

## Troubleshooting Permissions

### Common Issues

1. **"Insufficient privileges" errors**
   - Verify the Automation Account's managed identity has the required roles
   - Check if role assignments are at the correct scope
   - Allow 5-10 minutes for role assignment propagation

2. **Key Vault access denied**
   - Verify Key Vault access model (RBAC vs Access Policy)
   - Check if the secret name matches the deployment parameter
   - Ensure the Automation Account identity has appropriate access

3. **Log Analytics query failures**
   - Verify the Log Analytics Reader role assignment
   - Check if the workspace ID is correct
   - Ensure WVD diagnostic logs are configured

### Verification Commands

```powershell
# Check Automation Account managed identity
$aa = Get-AzAutomationAccount -ResourceGroupName "rg-automation" -Name "aa-avd-check-rebuild-logoff"
$aa.Identity.PrincipalId

# List role assignments for the managed identity
Get-AzRoleAssignment -ObjectId $aa.Identity.PrincipalId

# Test Key Vault access
$secret = Get-AzKeyVaultSecret -VaultName "kv-avd" -Name "LocalAdminPassword" -AsPlainText
```

## Role Assignment Outputs

The deployment provides the following outputs for verification:

- `automationAccountPrincipalId` - The managed identity principal ID
- `roleAssignmentIds` - Resource IDs of created role assignments
- `permissionsConfigured` - Boolean indicating successful permission setup

These outputs can be used for integration with other deployments or monitoring systems.
