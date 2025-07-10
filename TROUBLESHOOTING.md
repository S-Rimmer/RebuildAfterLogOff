# Troubleshooting: MSI Subscription Access Issues

## Problem
Error when Automation Account runbook executes:
```
Connect-AzAccount : The provided account MSI@50342 does not have access to subscription ID "xxx". 
Please try logging in with different credentials or a different subscription ID.
```

## Root Cause
This error occurs when the Automation Account's Managed Service Identity (MSI) doesn't have proper permissions to access the subscription, typically due to:

1. **Role Assignment Propagation Delay**: Azure role assignments can take 5-10 minutes to fully propagate
2. **Missing Subscription Reader Role**: The MSI needs Reader access at subscription level
3. **Runbook Execution Timing**: The runbook may start before permissions are ready

## Solutions Applied

### ✅ 1. Enhanced Role Assignments
**File: `roleAssignments.bicep`**
- Added explicit subscription Reader role assignment
- Ensured proper principalType and scope configuration

### ✅ 2. PowerShell Script Improvements  
**File: `AVD-CheckAndRebuildAtLogoff.ps1`**
- Added retry logic with 5-minute timeout
- Added connection verification before proceeding
- Added detailed error logging

### ✅ 3. Deployment Timing
**File: `deploy.bicep`**
- Increased initial schedule delay from 15 to 30 minutes
- Staggered subsequent executions (45, 60, 75 minutes)

## Manual Verification Steps

### Check Role Assignments
```powershell
# Get Automation Account details
$resourceGroup = "your-automation-rg"
$automationAccount = "your-automation-account"
$aa = Get-AzAutomationAccount -ResourceGroupName $resourceGroup -Name $automationAccount

# Check role assignments for the MSI
$principalId = $aa.Identity.PrincipalId
Get-AzRoleAssignment -ObjectId $principalId | Format-Table RoleDefinitionName, Scope
```

### Expected Role Assignments
The MSI should have these roles:
- **Reader** - Subscription level
- **Contributor** - AVD resource group level  
- **Log Analytics Reader** - Log Analytics workspace level
- **Key Vault Secrets User** - Key Vault level
- **Desktop Virtualization Virtual Machine Contributor** - AVD resource group level

### Test Subscription Access
```powershell
# Test connection manually
$subscriptionId = "your-subscription-id"
Connect-AzAccount -Identity -Subscription $subscriptionId

# Verify context
Get-AzContext | Format-List
```

## Immediate Fixes

### Option 1: Wait and Retry
- **Wait 10-15 minutes** after deployment for role assignments to propagate
- **Check Automation Account logs** in Azure Portal
- **Manually trigger runbook** to test

### Option 2: Manual Role Assignment
If automated role assignment fails, assign manually:

```powershell
# Get subscription and automation account details
$subscriptionId = "your-subscription-id"
$resourceGroup = "your-automation-rg" 
$automationAccount = "your-automation-account"

# Get the MSI principal ID
$aa = Get-AzAutomationAccount -ResourceGroupName $resourceGroup -Name $automationAccount
$principalId = $aa.Identity.PrincipalId

# Assign Reader role at subscription level
New-AzRoleAssignment -ObjectId $principalId -RoleDefinitionName "Reader" -Scope "/subscriptions/$subscriptionId"
```

### Option 3: Check Dependencies
Verify all required resources exist:
- ✅ Automation Account has system-assigned managed identity enabled
- ✅ Target subscription is accessible  
- ✅ AVD resource group exists
- ✅ Log Analytics workspace is accessible
- ✅ Key Vault exists and is accessible

## Prevention

### For Future Deployments:
1. **Use the updated templates** with enhanced error handling
2. **Monitor deployment outputs** to verify role assignments
3. **Test runbook manually** before relying on schedules
4. **Review Azure Activity Log** for any permission errors

### Monitoring:
- Set up alerts on Automation Account job failures
- Monitor role assignment creation in Activity Log
- Check runbook execution logs regularly

## Additional Resources

- [Azure Role Assignment Propagation](https://docs.microsoft.com/en-us/azure/role-based-access-control/troubleshooting#role-assignment-changes-are-not-being-detected)
- [Automation Account Managed Identity](https://docs.microsoft.com/en-us/azure/automation/automation-security-overview#managed-identities)
- [PowerShell Az Module Authentication](https://docs.microsoft.com/en-us/powershell/azure/authenticate-azureps)

## Contact
If the issue persists after following these steps:
1. Check the deployment outputs for role assignment IDs
2. Review Azure Activity Log for any failed operations
3. Enable verbose logging in the PowerShell script
4. Consider increasing the schedule delay further (60+ minutes)
