# Verify Template Spec Configuration and Deployment Status
# This script helps identify the current Template Spec version and verifies the configuration

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$TemplateSpecName,
    
    [string]$ExpectedVersion = "1.8"
)

Write-Output "=========================================="
Write-Output "Template Spec Verification"
Write-Output "=========================================="

try {
    # Get current Azure context
    $context = Get-AzContext
    if (-not $context) {
        Write-Error "Not connected to Azure. Run Connect-AzAccount first."
        exit 1
    }
    
    Write-Output "Connected to: $($context.Account.Id)"
    Write-Output "Subscription: $($context.Subscription.Name)"
    Write-Output ""
    
    # Get Template Spec information
    Write-Output "Checking Template Spec: $TemplateSpecName"
    Write-Output "Resource Group: $ResourceGroupName"
    Write-Output ""
    
    $templateSpec = Get-AzTemplateSpec -Name $TemplateSpecName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
    
    Write-Output "📋 Template Spec Details:"
    Write-Output "   Name: $($templateSpec.Name)"
    Write-Output "   Location: $($templateSpec.Location)"
    Write-Output "   Resource Group: $($templateSpec.ResourceGroupName)"
    Write-Output ""
    
    # List all versions
    Write-Output "📦 Available Versions:"
    $versions = Get-AzTemplateSpec -Name $TemplateSpecName -ResourceGroupName $ResourceGroupName | Select-Object -ExpandProperty Versions
    foreach ($version in $versions) {
        $status = if ($version.Name -eq $ExpectedVersion) { "✅ EXPECTED" } else { "⚠️  OLDER" }
        Write-Output "   Version $($version.Name) - $status"
    }
    Write-Output ""
    
    # Check if expected version exists
    try {
        $expectedVersionSpec = Get-AzTemplateSpec -Name $TemplateSpecName -ResourceGroupName $ResourceGroupName -Version $ExpectedVersion -ErrorAction Stop
        Write-Output "✅ Expected version $ExpectedVersion found!"
        Write-Output "   Resource ID: $($expectedVersionSpec.Versions.Id)"
        Write-Output ""
        
        # Analyze the template content for DSC parameters
        Write-Output "🔍 Analyzing Template Content..."
        $templateContent = $expectedVersionSpec.Versions.Template | ConvertFrom-Json
        
        # Look for DSC extension configuration
        $dscExtensions = $templateContent.resources | Where-Object { 
            $_.type -eq "Microsoft.Compute/virtualMachines/extensions" -and 
            $_.properties.type -eq "DSC" 
        }
        
        if ($dscExtensions) {
            Write-Output "📋 DSC Extension Configuration Found:"
            foreach ($ext in $dscExtensions) {
                $properties = $ext.properties.settings.properties
                Write-Output "   Extension Name: $($ext.name)"
                Write-Output "   Properties configured:"
                
                if ($properties.hostPoolName) { Write-Output "     ✅ hostPoolName" }
                if ($properties.registrationInfoToken) { Write-Output "     ✅ registrationInfoToken" }
                if ($properties.aadJoin) { Write-Output "     ✅ aadJoin" }
                
                # Check for problematic parameters
                if ($properties.domainJoined) { Write-Output "     ❌ domainJoined (UNSUPPORTED - WILL CAUSE ERROR)" }
                if ($properties.mdmId) { Write-Output "     ❌ mdmId (DEPRECATED)" }
                if ($properties.sessionHostConfigurationLastUpdateTime) { Write-Output "     ❌ sessionHostConfigurationLastUpdateTime (DEPRECATED)" }
                if ($properties.aadJoinPreview) { Write-Output "     ❌ aadJoinPreview (DEPRECATED)" }
                if ($properties.UseAgentDownloadEndpoint) { Write-Output "     ❌ UseAgentDownloadEndpoint (DEPRECATED)" }
            }
        } else {
            Write-Output "⚠️  No DSC extension found in template"
        }
    }
    catch {
        Write-Output "❌ Expected version $ExpectedVersion NOT found!"
        Write-Output "   You need to deploy the corrected template as version $ExpectedVersion"
        Write-Output ""
        Write-Output "📝 Action Required:"
        Write-Output "   1. Run Deploy-FixedTemplateSpec.ps1 to deploy version $ExpectedVersion"
        Write-Output "   2. Update your runbook parameter to use version $ExpectedVersion"
        Write-Output ""
        exit 1
    }
    
    Write-Output ""
    Write-Output "=========================================="
    Write-Output "Runbook Configuration Check"
    Write-Output "=========================================="
    Write-Output "In your runbook, ensure you're using:"
    Write-Output "   `$TemplateSpecVersion = `"$ExpectedVersion`""
    Write-Output ""
    Write-Output "The runbook parameters should include:"
    Write-Output "   enableAzureADJoin = `$true"
    Write-Output "   domainToJoin = `"`" (empty)"
    Write-Output "   domainUsername = `"`" (empty)"
    Write-Output "   domainPassword = `"`" (empty)"
    Write-Output ""
    Write-Output "=========================================="
    Write-Output "Summary"
    Write-Output "=========================================="
    
    if ($expectedVersionSpec) {
        Write-Output "✅ Template Spec version $ExpectedVersion is available"
        Write-Output "✅ Ready for deployment testing"
        Write-Output ""
        Write-Output "Next step: Test your runbook with version $ExpectedVersion"
    } else {
        Write-Output "❌ Template Spec version $ExpectedVersion is NOT available"
        Write-Output "❌ Deploy the corrected template first"
        Write-Output ""
        Write-Output "Next step: Run Deploy-FixedTemplateSpec.ps1"
    }
}
catch {
    Write-Error "Failed to verify Template Spec: $($_.Exception.Message)"
    Write-Output ""
    Write-Output "Possible causes:"
    Write-Output "1. Template Spec '$TemplateSpecName' doesn't exist in resource group '$ResourceGroupName'"
    Write-Output "2. You don't have permission to access the resource group"
    Write-Output "3. You're connected to the wrong subscription"
    Write-Output ""
    Write-Output "Try these commands to debug:"
    Write-Output "   Get-AzResourceGroup -Name '$ResourceGroupName'"
    Write-Output "   Get-AzTemplateSpec -ResourceGroupName '$ResourceGroupName'"
}
