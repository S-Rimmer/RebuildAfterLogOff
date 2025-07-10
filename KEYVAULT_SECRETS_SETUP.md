# Key Vault Secrets Setup Guide

## 🔑 **Required Secrets for AVD Rebuild Automation**

Based on your error log and deployment parameters, you need to create the following secret in your Key Vault.

### **Secret Required:**

| Secret Name | Purpose | Example Value |
|-------------|---------|---------------|
| `localadminpassword` | Local administrator password for AVD VMs | `P@ssw0rd123!` |

---

## 📋 **Setup Instructions**

### **Method 1: Azure Portal**

1. **Navigate to Key Vault**:
   ```
   Azure Portal → Key Vaults → kv-avdshr-dhe5hey2zqsug
   ```

2. **Create Secret**:
   - Go to **Secrets** in the left menu
   - Click **+ Generate/Import**
   - **Upload options**: Manual
   - **Name**: `localadminpassword`
   - **Value**: `YourSecurePassword123!` (use a strong password)
   - **Content type**: Leave empty
   - **Set activation date**: No
   - **Set expiration date**: No
   - **Enabled**: Yes
   - Click **Create**

### **Method 2: Azure CLI**

```bash
# Set variables
$keyVaultName = "kv-avdshr-dhe5hey2zqsug"
$secretName = "localadminpassword"
$secretValue = "YourSecurePassword123!"  # Use a strong password

# Create the secret
az keyvault secret set --vault-name $keyVaultName --name $secretName --value $secretValue
```

### **Method 3: Azure PowerShell**

```powershell
# Set variables
$keyVaultName = "kv-avdshr-dhe5hey2zqsug"
$secretName = "localadminpassword"
$secretValue = "YourSecurePassword123!"  # Use a strong password

# Create the secret
$secureString = ConvertTo-SecureString $secretValue -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -SecretValue $secureString
```

---

## 🔒 **Password Requirements**

Your VM administrator password must meet Azure VM password requirements:

### **Required:**
- ✅ 12-123 characters long
- ✅ At least 3 of the following:
  - Lowercase letters (a-z)
  - Uppercase letters (A-Z)
  - Numbers (0-9)
  - Special characters (!@#$%^&*()_+-=[]{}|;':\",./<>?)

### **Forbidden:**
- ❌ Cannot contain username or parts of username
- ❌ Cannot be common passwords like "Password123"
- ❌ Cannot contain spaces

### **Example Strong Passwords:**
```
Av3D@dm1n2024!
S3cur3P@ssw0rd!
Adm1n!Str0ng#2024
```

---

## 🔍 **Verification Steps**

### **Test Secret Access**

```powershell
# Test retrieving the secret
$keyVaultName = "kv-avdshr-dhe5hey2zqsug"
$secretName = "localadminpassword"

try {
    $secret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -AsPlainText
    Write-Output "✅ Secret retrieved successfully"
    Write-Output "Secret length: $($secret.Length) characters"
}
catch {
    Write-Error "❌ Failed to retrieve secret: $($_.Exception.Message)"
}
```

### **Test with Automation Account MSI**

```powershell
# This should be run in the context of the Automation Account (test runbook)
Connect-AzAccount -Identity
$secret = Get-AzKeyVaultSecret -VaultName "kv-avdshr-dhe5hey2zqsug" -Name "localadminpassword" -AsPlainText
Write-Output "MSI can access secret: $($secret -ne $null)"
```

---

## 🚨 **Security Best Practices**

### **1. Use Strong Passwords**
- Generate passwords using a password manager
- Minimum 15 characters recommended
- Include all character types

### **2. Regular Rotation**
```powershell
# Set up secret rotation (optional)
$expirationDate = (Get-Date).AddDays(90)  # 90 days from now
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -SecretValue $secureString -Expires $expirationDate
```

### **3. Access Monitoring**
- Enable Key Vault logging
- Monitor secret access in Azure Monitor
- Set up alerts for unusual access patterns

### **4. Backup Secrets**
```powershell
# Export secret for backup (secure location only)
$secret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -AsPlainText
# Store $secret in secure backup system
```

---

## 🔧 **For Your Current Error**

Based on your error log, create the secret immediately:

```powershell
# Quick fix for current deployment
$keyVaultName = "kv-avdshr-dhe5hey2zqsug"
$secretName = "localadminpassword"
$secretValue = "Avd@Admin123!"  # Change this to your preferred password

# Create the secret
$secureString = ConvertTo-SecureString $secretValue -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -SecretValue $secureString

Write-Output "✅ Secret created successfully"
```

---

## 🎯 **Deployment Parameter Mapping**

In your deployment, this maps to:

| Deployment Parameter | Value | Key Vault Secret |
|---------------------|-------|------------------|
| `KeyVaultName` | `kv-avdshr-dhe5hey2zqsug` | Key Vault name |
| `KeyVaultVMAdmin` | `localadminpassword` | Secret name |

The automation script retrieves this secret and uses it as the local administrator password when creating new VMs through the Template Spec.

---

## ⚠️ **Important Notes**

1. **Create the secret BEFORE** running the automation
2. **Ensure MSI has "Key Vault Secrets User" role** on the Key Vault
3. **Test secret access** before relying on automation
4. **Document the password** in your organization's secure password system
5. **Consider password rotation** for security compliance

After creating this secret, your automation should be able to retrieve the VM admin password successfully.
