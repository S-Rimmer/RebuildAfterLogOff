# Test Fresh Azure AD Template Spec Deployment
# This script helps test and verify the fresh template spec deployment

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$TemplateSpecName,
    
    [Parameter(Mandatory=$true)]
    [string]$HostPoolName,
    
    [Parameter(Mandatory=$true)]
    [string]$AVDResourceGroup,
    
    [string]$Version = "2.0"
)

Write-Output "=========================================="
Write-Output "Testing Fresh Azure AD Template Spec"
Write-Output "=========================================="

try {
    # Check if connected to Azure
    $context = Get-AzContext
    if (-not $context) {
        Write-Error "Not connected to Azure. Run Connect-AzAccount first."
        exit 1
    }
    
    Write-Output "✅ Connected to Azure: $($context.Account.Id)"
    Write-Output "📋 Subscription: $($context.Subscription.Name)"
    Write-Output ""
    
    # 1. Verify Template Spec exists
    Write-Output "🔍 Step 1: Verifying Template Spec..."
    try {
        $templateSpec = Get-AzTemplateSpec -Name $TemplateSpecName -ResourceGroupName $ResourceGroupName -Version $Version -ErrorAction Stop
        Write-Output "✅ Template Spec found: $($templateSpec.Name) v$Version"
        Write-Output "   Resource ID: $($templateSpec.Versions.Id)"
    }
    catch {
        Write-Output "❌ Template Spec not found: $TemplateSpecName v$Version"
        Write-Output "   Deploy the template first using Deploy-FreshAADTemplateSpec.ps1"
        exit 1
    }
    
    # 2. Check Host Pool configuration
    Write-Output ""
    Write-Output "🔍 Step 2: Checking Host Pool configuration..."
    try {
        $hostPool = Get-AzWvdHostPool -Name $HostPoolName -ResourceGroupName $AVDResourceGroup -ErrorAction Stop
        Write-Output "✅ Host Pool found: $($hostPool.Name)"
        Write-Output "   Type: $($hostPool.HostPoolType)"
        Write-Output "   Load Balancer Type: $($hostPool.LoadBalancerType)"
        
        # Check if domain joined
        if ([string]::IsNullOrEmpty($hostPool.CustomRdpProperty) -or $hostPool.CustomRdpProperty -notlike "*domain*") {
            Write-Output "✅ Host Pool configured for Azure AD (no domain requirements)"
        } else {
            Write-Output "⚠️  Host Pool may have domain-related settings"
        }
    }
    catch {
        Write-Output "❌ Host Pool not found: $HostPoolName"
        Write-Output "   Verify the host pool exists and you have access"
        exit 1
    }
    
    # 3. Check existing session hosts
    Write-Output ""
    Write-Output "🔍 Step 3: Checking existing session hosts..."
    try {
        $sessionHosts = Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $AVDResourceGroup -ErrorAction SilentlyContinue
        if ($sessionHosts) {
            Write-Output "📋 Found $($sessionHosts.Count) session host(s):"
            foreach ($host in $sessionHosts) {
                $hostName = ($host.Name -split '/')[1]
                Write-Output "   - $hostName (Status: $($host.Status))"
                
                # Check for domain health issues
                if ($host.Status -eq "Unavailable" -or $host.HealthCheckResults) {
                    Write-Output "     ⚠️  May have health check issues"
                }
            }
        } else {
            Write-Output "📋 No existing session hosts found"
        }
    }
    catch {
        Write-Output "⚠️  Could not retrieve session hosts"
    }
    
    # 4. Generate test deployment command
    Write-Output ""
    Write-Output "🔍 Step 4: Generating test deployment command..."
    
    $testVMName = "test-aad-vm-$(Get-Date -Format 'MMdd')"
    
    Write-Output "📋 Sample deployment command for testing:"
    Write-Output ""
    Write-Output "New-AzResourceGroupDeployment ``"
    Write-Output "    -ResourceGroupName '$AVDResourceGroup' ``"
    Write-Output "    -TemplateSpecId '$($templateSpec.Versions.Id)' ``"
    Write-Output "    -vmName '$testVMName' ``"
    Write-Output "    -vmSize 'Standard_D2s_v3' ``"
    Write-Output "    -adminUsername 'azureuser' ``"
    Write-Output "    -adminPassword (ConvertTo-SecureString 'YourPassword123!' -AsPlainText -Force) ``"
    Write-Output "    -hostPoolName '$HostPoolName' ``"
    Write-Output "    -resourceGroupName '$AVDResourceGroup' ``"
    Write-Output "    -vnetName 'YourVNetName' ``"
    Write-Output "    -subnetName 'YourSubnetName' ``"
    Write-Output "    -registrationInfoToken 'YourRegistrationToken' ``"
    Write-Output "    -useGalleryImage `$true ``"
    Write-Output "    -imageId 'YourImageId' ``"
    Write-Output "    -enableAzureADJoin `$true ``"
    Write-Output "    -Verbose"
    Write-Output ""
    
    # 5. Pre-deployment checklist
    Write-Output "=========================================="
    Write-Output "PRE-DEPLOYMENT CHECKLIST"
    Write-Output "=========================================="
    Write-Output "✅ Template Spec v$Version deployed and verified"
    Write-Output "✅ Host Pool exists and accessible"
    Write-Output "⏳ Update VNet resource group in template (line 95)"
    Write-Output "⏳ Obtain valid registration token"
    Write-Output "⏳ Prepare VM parameters (name, size, credentials)"
    Write-Output "⏳ Verify network connectivity to Azure AD endpoints"
    Write-Output ""
    
    # 6. Expected outcomes
    Write-Output "=========================================="
    Write-Output "EXPECTED DEPLOYMENT OUTCOMES"
    Write-Output "=========================================="
    Write-Output "After successful deployment with fresh template:"
    Write-Output ""
    Write-Output "✅ VM Creation:"
    Write-Output "   - VM created with Trusted Launch security"
    Write-Output "   - System-assigned managed identity configured"
    Write-Output "   - Network interface and disk with delete options set"
    Write-Output ""
    Write-Output "✅ Azure AD Join:"
    Write-Output "   - AADLoginForWindows extension installed"
    Write-Output "   - VM joined to Azure AD tenant"
    Write-Output "   - No domain join attempts"
    Write-Output ""
    Write-Output "✅ AVD Agent:"
    Write-Output "   - DSC extension deploys without parameter errors"
    Write-Output "   - AVD agent installs and registers successfully"
    Write-Output "   - Session host appears as 'Available'"
    Write-Output ""
    Write-Output "✅ Health Checks:"
    Write-Output "   - DomainJoinedCheck: PASS (disabled)"
    Write-Output "   - DomainTrustCheck: PASS (disabled)"
    Write-Output "   - AADJoinedCheck: PASS"
    Write-Output "   - All other health checks: PASS"
    Write-Output ""
    Write-Output "=========================================="
    Write-Output "NEXT STEPS"
    Write-Output "=========================================="
    Write-Output "1. Update the VNet resource group in fresh-aad-templatespec.bicep"
    Write-Output "2. Update your runbook to use Template Spec version $Version"
    Write-Output "3. Test deployment with a single VM first"
    Write-Output "4. Monitor deployment logs and session host health"
    Write-Output "5. If successful, deploy to production environment"
    Write-Output ""
    Write-Output "🎯 The fresh template should resolve all domain health check issues!"
}
catch {
    Write-Error "Test failed: $($_.Exception.Message)"
    exit 1
}
