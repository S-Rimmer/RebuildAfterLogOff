# Deploy Corrected Template Spec - Azure AD Join Fix
# This script deploys the corrected Template Spec that removes unsupported DSC parameters

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$TemplateSpecName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [string]$Version = "1.8",
    
    [string]$TemplateFile = "sample-templatespec.bicep"
)

Write-Output "=========================================="
Write-Output "Deploying Corrected AVD Template Spec"
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
    Write-Output "Deploying Template Spec..."
    
    $templateSpec = New-AzTemplateSpec `
        -ResourceGroupName $ResourceGroupName `
        -Name $TemplateSpecName `
        -Version $Version `
        -Location $Location `
        -TemplateFile $TemplateFile `
        -DisplayName "AVD Session Host Template v$Version - Azure AD Join Fixed" `
        -Description "Fixed DSC extension to only use supported parameters: hostPoolName, registrationInfoToken, aadJoin. Removes unsupported parameters like domainJoined, mdmId, etc." `
        -Force `
        -Verbose
    
    Write-Output "✅ Template Spec deployed successfully!"
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
    Write-Output "NEXT STEPS:"
    Write-Output "=========================================="
    Write-Output "1. Update your runbook to use version $Version:"
    Write-Output "   `$TemplateSpecVersion = `"$Version`""
    Write-Output ""
    Write-Output "2. Test the deployment with your runbook"
    Write-Output ""
    Write-Output "3. Monitor for the following improvements:"
    Write-Output "   ✅ No DSC extension parameter errors"
    Write-Output "   ✅ Successful Azure AD join"
    Write-Output "   ✅ AVD agent registration"
    Write-Output "   ✅ Session host health checks pass"
    Write-Output "=========================================="
}
catch {
    Write-Error "Failed to deploy Template Spec: $($_.Exception.Message)"
    Write-Output "Full error details:"
    Write-Output $_.Exception
    exit 1
}
