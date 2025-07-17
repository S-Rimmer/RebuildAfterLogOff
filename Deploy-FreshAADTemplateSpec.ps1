# Deploy Fresh Azure AD-Only AVD Template Spec
# This script deploys the fresh template spec designed specifically for Azure AD-joined session hosts

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$TemplateSpecName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [string]$Version = "2.1",
    
    [string]$TemplateFile = "fresh-aad-templatespec.bicep"
)

Write-Output "=========================================="
Write-Output "Deploying Fresh Azure AD-Only AVD Template Spec"
Write-Output "=========================================="
Write-Output "Resource Group: $ResourceGroupName"
Write-Output "Template Spec Name: $TemplateSpecName"
Write-Output "Version: $Version"
Write-Output "Location: $Location"
Write-Output "Template File: $TemplateFile"
Write-Output "=========================================="

# Check if template file exists
if (-not (Test-Path $TemplateFile)) {
    Write-Error "Template file not found: $TemplateFile"
    Write-Output "Current directory: $(Get-Location)"
    Write-Output "Files in current directory:"
    Get-ChildItem | Select-Object Name, Length, LastWriteTime
    exit 1
}

# Check if already connected to Azure
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Output "Not connected to Azure. Please run Connect-AzAccount first."
        Connect-AzAccount
    }
    Write-Output "Connected to Azure as: $($context.Account.Id)"
    Write-Output "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"
}
catch {
    Write-Error "Failed to get Azure context: $($_.Exception.Message)"
    exit 1
}

# Check if resource group exists
try {
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
    Write-Output "Resource group found: $($rg.ResourceGroupName) in $($rg.Location)"
}
catch {
    Write-Error "Resource group '$ResourceGroupName' not found: $($_.Exception.Message)"
    exit 1
}

# Deploy the Template Spec
try {
    Write-Output "Deploying Fresh Azure AD-Only Template Spec..."
    
    $templateSpec = New-AzTemplateSpec `
        -ResourceGroupName $ResourceGroupName `
        -Name $TemplateSpecName `
        -Version $Version `
        -Location $Location `
        -TemplateFile $TemplateFile `
        -DisplayName "Fresh AVD Session Host Template v$Version - Azure AD Only" `
        -Description "Fresh template designed specifically for Azure AD-joined AVD session hosts. Includes registry pre-configuration, health check optimization, proper AVD agent setup, and mdmId support for latest AADLoginForWindows extension requirements." `
        -Force `
        -Verbose
    
    Write-Output "✅ Fresh Template Spec deployed successfully!"
    Write-Output "Template Spec ID: $($templateSpec.Id)"
    Write-Output "Version: $($templateSpec.Versions.Name)"
    
    # Verify the deployment
    Write-Output ""
    Write-Output "Verifying deployment..."
    $verifySpec = Get-AzTemplateSpec -Name $TemplateSpecName -ResourceGroupName $ResourceGroupName -Version $Version
    Write-Output "✅ Verification successful!"
    Write-Output "Template Spec: $($verifySpec.Name)"
    Write-Output "Version: $Version"
    Write-Output "Resource ID: $($verifySpec.Versions.Id)"
    
    Write-Output ""
    Write-Output "=========================================="
    Write-Output "FRESH TEMPLATE FEATURES:"
    Write-Output "=========================================="
    Write-Output "✅ Azure AD join only (no domain join attempts)"
    Write-Output "✅ Registry pre-configuration for Azure AD environment"
    Write-Output "✅ Health check optimization to prevent domain failures"
    Write-Output "✅ Latest AVD DSC module with minimal required parameters"
    Write-Output "✅ Post-deployment configuration for health check compliance"
    Write-Output "✅ System-assigned managed identity for security"
    Write-Output "✅ Trusted Launch VM support with security features"
    Write-Output "✅ Proper cleanup configuration for automation"
    Write-Output ""
    Write-Output "=========================================="
    Write-Output "NEXT STEPS:"
    Write-Output "=========================================="
    Write-Output "1. Update your runbook to use version ${Version}:"
    Write-Output "   `$TemplateSpecVersion = `"${Version}`""
    Write-Output ""
    Write-Output "2. Update the VNet resource group in the template:"
    Write-Output "   Edit line 95 in fresh-aad-templatespec.bicep"
    Write-Output "   Change 'EST2_SharedResources' to your VNet's resource group"
    Write-Output ""
    Write-Output "3. Test the deployment with your runbook"
    Write-Output ""
    Write-Output "4. Expected results:"
    Write-Output "   ✅ No DSC extension parameter errors"
    Write-Output "   ✅ Successful Azure AD join"
    Write-Output "   ✅ AVD agent registration without domain issues"
    Write-Output "   ✅ All health checks pass (including DomainJoinedCheck and DomainTrustCheck)"
    Write-Output "   ✅ Session host shows as 'Available' in AVD admin center"
    Write-Output "=========================================="
}
catch {
    Write-Error "Failed to deploy Template Spec: $($_.Exception.Message)"
    Write-Output "Full error details:"
    Write-Output $_.Exception
    exit 1
}
