# Emergency Fix Guide for Deployed Environment

## 🚨 **Critical Issues Fixed in Code:**

1. **Key Vault Access Error** - Role assignment propagation
2. **VM Object Structure** - Null reference errors  
3. **Image Type Detection** - Gallery vs Marketplace logic
4. **Error Handling** - Added null checks and try/catch blocks

## 🔧 **Immediate Fixes for Your Current Deployment**

### **Fix 1: Key Vault Permissions (PRIORITY 1)**

The MSI needs proper Key Vault access. Run these PowerShell commands:

```powershell
# Get your Automation Account's MSI Principal ID
$subscriptionId = "1c47846d-f4bb-4aeb-a0dd-fcf8acdd6d79"
$automationRG = "your-automation-rg"  # Replace with your actual RG
$automationAccountName = "your-automation-account"  # Replace with your actual name
$keyVaultName = "kv-avdshr-dhe5hey2zqsug"  # From your error log

# Connect to Azure
Connect-AzAccount

# Get the MSI Principal ID 
$aa = Get-AzAutomationAccount -ResourceGroupName $automationRG -Name $automationAccountName
$principalId = $aa.Identity.PrincipalId
Write-Output "MSI Principal ID: $principalId"

# Assign Key Vault Secrets User role
$keyVault = Get-AzKeyVault -VaultName $keyVaultName
New-AzRoleAssignment -ObjectId $principalId -RoleDefinitionName "Key Vault Secrets User" -Scope $keyVault.ResourceId

# Verify the assignment
Get-AzRoleAssignment -ObjectId $principalId | Where-Object {$_.RoleDefinitionName -like "*Key Vault*"}
```

### **Fix 2: Update PowerShell Runbook**

Replace the runbook script with the fixed version:

```powershell
# In Azure Portal:
# 1. Go to Automation Account > Runbooks
# 2. Select "AVD-CheckAndRebuildAtLogoff" 
# 3. Click "Edit"
# 4. Replace content with the updated script
# 5. Click "Save" then "Publish"
```

### **Fix 3: Test Key Vault Access**

Verify the Key Vault secret exists:

```powershell
# Check if the secret exists
Get-AzKeyVaultSecret -VaultName "kv-avdshr-dhe5hey2zqsug" -Name "localadminpassword"

# Test access with MSI (run this in a test runbook)
$secret = Get-AzKeyVaultSecret -VaultName "kv-avdshr-dhe5hey2zqsug" -Name "localadminpassword" -AsPlainText
Write-Output "Secret retrieved successfully"
```

### **Fix 4: Verify Template Spec Parameters**

Your image ID suggests you're using a Gallery image, but it's being detected as marketplace. Verify your Template Spec supports both:

```powershell
# Check your image ID format
$imageId = "/subscriptions/1c47846d-f4bb-4aeb-a0dd-fcf8acdd6d79/resourceGroups/RG-AVD-USE-SHARED-SERVICES/providers/Microsoft.Compute/galleries/gal_avd_use/images/avd-win11_22h2-new"

# This is a Gallery image (contains "/galleries/") 
# Make sure your Template Spec has useGalleryImage parameter
```

## 📋 **Step-by-Step Recovery Process**

### **Step 1: Fix Key Vault Access (15 minutes)**
```powershell
# Run the Key Vault permission commands above
# Wait 5-10 minutes for propagation
```

### **Step 2: Update Runbook Script (10 minutes)**
1. Go to Azure Portal → Automation Account
2. Navigate to Runbooks → AVD-CheckAndRebuildAtLogoff
3. Click "Edit" 
4. Replace with updated script (see files in repository)
5. Save and Publish

### **Step 3: Test Manually (5 minutes)**
```powershell
# Test the runbook manually
# 1. Go to Runbooks → AVD-CheckAndRebuildAtLogoff
# 2. Click "Start"
# 3. Monitor output for errors
```

### **Step 4: Validate Role Assignments**
```powershell
# Check all role assignments for the MSI
$principalId = "4f9bb86b-6f8d-4407-911f-b7d5a8f3163d"  # From your error log
Get-AzRoleAssignment -ObjectId $principalId | Format-Table RoleDefinitionName, Scope
```

Expected roles:
- ✅ Reader (Subscription level)
- ✅ Contributor (AVD resource group)
- ✅ Key Vault Secrets User (Key Vault)
- ✅ Log Analytics Reader (Log Analytics workspace)
- ✅ Desktop Virtualization Virtual Machine Contributor (AVD resource group)

## 🔍 **Quick Diagnostics**

### **Check Current State:**
```powershell
# 1. Verify Automation Account Identity
Get-AzAutomationAccount -ResourceGroupName "your-rg" -Name "your-aa" | Select-Object Identity

# 2. Check recent runbook executions
Get-AzAutomationJob -AutomationAccountName "your-aa" -ResourceGroupName "your-rg" | Select-Object -First 5

# 3. Test Key Vault access
$context = Get-AzContext
Write-Output "Current context: $($context.Account.Id)"
```

### **Validation Commands:**
```powershell
# Test image detection logic
$imageId = "/subscriptions/1c47846d-f4bb-4aeb-a0dd-fcf8acdd6d79/resourceGroups/RG-AVD-USE-SHARED-SERVICES/providers/Microsoft.Compute/galleries/gal_avd_use/images/avd-win11_22h2-new"
$isGalleryImage = $imageId -match "^/subscriptions/.*/resourceGroups/.*/providers/Microsoft\.Compute/galleries/.*/images/.*"
Write-Output "Is Gallery Image: $isGalleryImage"  # Should be True

# Test Template Spec access
Get-AzTemplateSpec -Name "your-template-spec" -ResourceGroupName "your-template-spec-rg"
```

## ⏰ **Timeline for Fixes**

| Task | Time | Priority |
|------|------|----------|
| Fix Key Vault permissions | 5 min | HIGH |
| Wait for propagation | 10 min | HIGH |
| Update runbook script | 10 min | HIGH |
| Test execution | 5 min | MEDIUM |
| Full validation | 10 min | LOW |

**Total: ~40 minutes**

## 🆘 **If Issues Persist**

1. **Check Azure Activity Log** for failed role assignments
2. **Review Key Vault Access Policies** (if using access policies instead of RBAC)
3. **Verify Network Access** to Key Vault (firewall rules)
4. **Test Template Spec** deployment manually

## 📞 **Emergency Contacts**

If critical production impact:
1. Disable the automation schedule temporarily
2. Review all role assignments
3. Test each component individually
4. Consider manual VM rebuilds while troubleshooting

The updated code includes comprehensive error handling and should resolve all the issues identified in your error log.
