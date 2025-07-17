# Grant Complete Permissions for AVD Session Host Management
# This script grants all necessary permissions for the Automation Account to manage AVD session hosts and Azure AD devices

param(
    [Parameter(Mandatory = $true)]
    [string]$AutomationAccountName,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$AVDResourceGroupName = $ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory = $false)]
    [string]$TemplateSpecResourceGroupName = $ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$LogAnalyticsWorkspaceResourceGroupName = $ResourceGroupName
)

Write-Host "🔐 Granting comprehensive permissions for AVD session host management..." -ForegroundColor Cyan

try {
    # Connect to required modules
    if (-not (Get-Module Microsoft.Graph -ListAvailable)) {
        Write-Host "📦 Installing Microsoft Graph PowerShell module..." -ForegroundColor Yellow
        Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber
    }

    # Connect to Microsoft Graph
    Write-Host "🔗 Connecting to Microsoft Graph..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes "Application.ReadWrite.All", "AppRoleAssignment.ReadWrite.All", "Directory.ReadWrite.All"

    # Connect to Azure
    Write-Host "🔗 Connecting to Azure..." -ForegroundColor Yellow
    Connect-AzAccount
    Set-AzContext -SubscriptionId $SubscriptionId

    # Get the Automation Account's managed identity
    Write-Host "🔍 Getting Automation Account managed identity..." -ForegroundColor Yellow
    $managedIdentity = Get-MgServicePrincipal -Filter "DisplayName eq '$AutomationAccountName'"
    
    if (-not $managedIdentity) {
        throw "Managed identity not found for Automation Account '$AutomationAccountName'. Ensure system-assigned managed identity is enabled."
    }

    Write-Host "✅ Found managed identity: $($managedIdentity.DisplayName)" -ForegroundColor Green
    Write-Host "   Principal ID: $($managedIdentity.Id)" -ForegroundColor Gray

    # ========== MICROSOFT GRAPH PERMISSIONS ==========
    Write-Host "`n📋 Granting Microsoft Graph API permissions..." -ForegroundColor Cyan
    
    $graphSP = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"
    
    # Required Graph permissions for AVD + Azure AD management
    $requiredPermissions = @(
        "Device.ReadWrite.All",           # Delete Azure AD devices
        "Directory.ReadWrite.All",        # Manage Azure AD objects
        "DeviceManagementManagedDevices.ReadWrite.All"  # Intune device management (if using MDM)
    )
    
    foreach ($permissionName in $requiredPermissions) {
        $permission = $graphSP.AppRoles | Where-Object { $_.Value -eq $permissionName }
        
        if ($permission) {
            # Check if already assigned
            $existingAssignment = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentity.Id | 
                Where-Object { $_.AppRoleId -eq $permission.Id }
            
            if ($existingAssignment) {
                Write-Host "   ✅ $permissionName - Already assigned" -ForegroundColor Green
            } else {
                try {
                    $body = @{
                        principalId = $managedIdentity.Id
                        resourceId = $graphSP.Id
                        appRoleId = $permission.Id
                    }
                    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentity.Id -BodyParameter $body | Out-Null
                    Write-Host "   ✅ $permissionName - Granted" -ForegroundColor Green
                } catch {
                    Write-Host "   ❌ $permissionName - Failed: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "   ⚠️  $permissionName - Permission not found" -ForegroundColor Yellow
        }
    }

    # ========== AZURE RBAC PERMISSIONS ==========
    Write-Host "`n📋 Granting Azure RBAC permissions..." -ForegroundColor Cyan
    
    # Core permissions needed for AVD session host management
    $rbacAssignments = @(
        @{
            RoleName = "Virtual Machine Contributor"
            Scope = "/subscriptions/$SubscriptionId/resourceGroups/$AVDResourceGroupName"
            Description = "Create/delete VMs in AVD resource group"
        },
        @{
            RoleName = "Network Contributor" 
            Scope = "/subscriptions/$SubscriptionId/resourceGroups/$AVDResourceGroupName"
            Description = "Manage network interfaces for VMs"
        },
        @{
            RoleName = "Storage Account Contributor"
            Scope = "/subscriptions/$SubscriptionId/resourceGroups/$AVDResourceGroupName" 
            Description = "Manage VM disks and storage"
        },
        @{
            RoleName = "Desktop Virtualization Contributor"
            Scope = "/subscriptions/$SubscriptionId/resourceGroups/$AVDResourceGroupName"
            Description = "Manage AVD host pools and session hosts"
        },
        @{
            RoleName = "Template Spec Reader"
            Scope = "/subscriptions/$SubscriptionId/resourceGroups/$TemplateSpecResourceGroupName"
            Description = "Read and deploy template specs"
        },
        @{
            RoleName = "Log Analytics Reader"
            Scope = "/subscriptions/$SubscriptionId/resourceGroups/$LogAnalyticsWorkspaceResourceGroupName"
            Description = "Query Log Analytics for session data"
        }
    )
    
    # Add Key Vault permissions if specified
    if ($KeyVaultName) {
        $rbacAssignments += @{
            RoleName = "Key Vault Secrets User"
            Scope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$KeyVaultName"
            Description = "Read secrets from Key Vault"
        }
    }
    
    foreach ($assignment in $rbacAssignments) {
        try {
            # Check if role assignment already exists
            $existingAssignment = Get-AzRoleAssignment -ObjectId $managedIdentity.Id -RoleDefinitionName $assignment.RoleName -Scope $assignment.Scope -ErrorAction SilentlyContinue
            
            if ($existingAssignment) {
                Write-Host "   ✅ $($assignment.RoleName) - Already assigned to $($assignment.Scope)" -ForegroundColor Green
            } else {
                New-AzRoleAssignment -ObjectId $managedIdentity.Id -RoleDefinitionName $assignment.RoleName -Scope $assignment.Scope | Out-Null
                Write-Host "   ✅ $($assignment.RoleName) - Granted to $($assignment.Scope)" -ForegroundColor Green
                Write-Host "      └─ $($assignment.Description)" -ForegroundColor Gray
            }
        } catch {
            Write-Host "   ❌ $($assignment.RoleName) - Failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host "`n🎉 Permission assignment completed!" -ForegroundColor Green
    Write-Host "`n📋 Summary of granted permissions:" -ForegroundColor Cyan
    Write-Host "   Microsoft Graph API:" -ForegroundColor White
    Write-Host "   ├─ Device.ReadWrite.All (Delete Azure AD devices)" -ForegroundColor Gray
    Write-Host "   ├─ Directory.ReadWrite.All (Manage Azure AD objects)" -ForegroundColor Gray
    Write-Host "   └─ DeviceManagementManagedDevices.ReadWrite.All (Intune devices)" -ForegroundColor Gray
    Write-Host "   Azure RBAC:" -ForegroundColor White
    Write-Host "   ├─ Virtual Machine Contributor" -ForegroundColor Gray
    Write-Host "   ├─ Network Contributor" -ForegroundColor Gray
    Write-Host "   ├─ Storage Account Contributor" -ForegroundColor Gray
    Write-Host "   ├─ Desktop Virtualization Contributor" -ForegroundColor Gray
    Write-Host "   ├─ Template Spec Reader" -ForegroundColor Gray
    Write-Host "   ├─ Log Analytics Reader" -ForegroundColor Gray
    if ($KeyVaultName) {
        Write-Host "   └─ Key Vault Secrets User" -ForegroundColor Gray
    }
    
    Write-Host "`n⚠️  Important notes:" -ForegroundColor Yellow
    Write-Host "   • Permissions may take 5-15 minutes to propagate" -ForegroundColor Gray
    Write-Host "   • Test the runbook after waiting for propagation" -ForegroundColor Gray
    Write-Host "   • Monitor runbook logs for permission-related errors" -ForegroundColor Gray
    Write-Host "   • Azure AD device cleanup should now work automatically" -ForegroundColor Gray

} catch {
    Write-Error "❌ Failed to assign permissions: $($_.Exception.Message)"
    Write-Host "`n🔧 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   1. Ensure you have Global Administrator permissions" -ForegroundColor Gray
    Write-Host "   2. Verify Automation Account has system-assigned managed identity enabled" -ForegroundColor Gray
    Write-Host "   3. Check that you're connected to the correct tenant and subscription" -ForegroundColor Gray
    Write-Host "   4. Some permissions may require Privileged Role Administrator" -ForegroundColor Gray
}
