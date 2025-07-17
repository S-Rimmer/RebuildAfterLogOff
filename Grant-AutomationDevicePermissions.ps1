# Grant Device.ReadWrite.All permission to Automation Account Managed Identity
# This script uses the Microsoft Graph PowerShell module (most reliable method)

param(
    [Parameter(Mandatory = $true)]
    [string]$AutomationAccountName,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId
)

Write-Host "🔐 Granting Device.ReadWrite.All permission to Automation Account managed identity..." -ForegroundColor Cyan

try {
    # Check if Microsoft Graph module is installed
    if (-not (Get-Module Microsoft.Graph -ListAvailable)) {
        Write-Host "📦 Installing Microsoft Graph PowerShell module..." -ForegroundColor Yellow
        Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber
    }

    # Import required modules
    Import-Module Microsoft.Graph.Applications
    Import-Module Microsoft.Graph.Identity.Governance

    # Connect to Microsoft Graph
    Write-Host "� Connecting to Microsoft Graph..." -ForegroundColor Yellow
    $graphContext = Get-MgContext
    if (-not $graphContext) {
        Connect-MgGraph -Scopes "Application.ReadWrite.All", "AppRoleAssignment.ReadWrite.All"
        Write-Host "✅ Connected to Microsoft Graph" -ForegroundColor Green
    } else {
        Write-Host "✅ Already connected to Microsoft Graph" -ForegroundColor Green
    }

    # Get the managed identity of the Automation Account
    Write-Host "🔍 Getting managed identity for Automation Account: $AutomationAccountName" -ForegroundColor Yellow
    $managedIdentity = Get-MgServicePrincipal -Filter "DisplayName eq '$AutomationAccountName'"
    
    if (-not $managedIdentity) {
        throw "Managed identity not found for Automation Account '$AutomationAccountName'. Ensure system-assigned managed identity is enabled."
    }

    Write-Host "✅ Found managed identity: $($managedIdentity.Id)" -ForegroundColor Green
    Write-Host "   Display Name: $($managedIdentity.DisplayName)" -ForegroundColor Gray
    Write-Host "   App ID: $($managedIdentity.AppId)" -ForegroundColor Gray

    # Get Microsoft Graph service principal
    Write-Host "🔍 Getting Microsoft Graph service principal..." -ForegroundColor Yellow
    $graphServicePrincipal = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"
    
    if (-not $graphServicePrincipal) {
        throw "Microsoft Graph service principal not found"
    }

    Write-Host "✅ Found Microsoft Graph service principal: $($graphServicePrincipal.Id)" -ForegroundColor Green

    # Find the Device.ReadWrite.All permission
    Write-Host "🔍 Looking for Device.ReadWrite.All permission..." -ForegroundColor Yellow
    $devicePermission = $graphServicePrincipal.AppRoles | Where-Object { $_.Value -eq "Device.ReadWrite.All" }
    
    if (-not $devicePermission) {
        throw "Device.ReadWrite.All permission not found in Microsoft Graph app roles"
    }

    Write-Host "✅ Found Device.ReadWrite.All permission: $($devicePermission.Id)" -ForegroundColor Green
    Write-Host "   Permission: $($devicePermission.Value)" -ForegroundColor Gray
    Write-Host "   Description: $($devicePermission.Description)" -ForegroundColor Gray

    # Check if permission is already assigned
    Write-Host "🔍 Checking existing app role assignments..." -ForegroundColor Yellow
    $existingAssignments = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentity.Id
    $existingAssignment = $existingAssignments | Where-Object { 
        $_.AppRoleId -eq $devicePermission.Id -and $_.ResourceId -eq $graphServicePrincipal.Id 
    }

    if ($existingAssignment) {
        Write-Host "✅ Device.ReadWrite.All permission is already assigned!" -ForegroundColor Green
        Write-Host "   Assignment ID: $($existingAssignment.Id)" -ForegroundColor Gray
        Write-Host "   Created: $($existingAssignment.CreatedDateTime)" -ForegroundColor Gray
    }
    else {
        # Assign the permission
        Write-Host "🔧 Assigning Device.ReadWrite.All permission..." -ForegroundColor Yellow
        
        $body = @{
            principalId = $managedIdentity.Id
            resourceId = $graphServicePrincipal.Id
            appRoleId = $devicePermission.Id
        }
        
        $roleAssignment = New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentity.Id -BodyParameter $body
        
        Write-Host "✅ Successfully assigned Device.ReadWrite.All permission!" -ForegroundColor Green
        Write-Host "   Assignment ID: $($roleAssignment.Id)" -ForegroundColor Gray
        Write-Host "   Created: $($roleAssignment.CreatedDateTime)" -ForegroundColor Gray
    }

    Write-Host "" -ForegroundColor White
    Write-Host "🎉 Permission assignment completed successfully!" -ForegroundColor Green
    Write-Host "" -ForegroundColor White
    Write-Host "📋 Summary:" -ForegroundColor Cyan
    Write-Host "   Automation Account: $AutomationAccountName" -ForegroundColor Gray
    Write-Host "   Managed Identity: $($managedIdentity.DisplayName)" -ForegroundColor Gray
    Write-Host "   Permission: Device.ReadWrite.All" -ForegroundColor Gray
    Write-Host "   Status: ✅ Granted" -ForegroundColor Green
    Write-Host "" -ForegroundColor White
    Write-Host "⚠️  Note: It may take 5-15 minutes for the permission to take effect." -ForegroundColor Yellow
    Write-Host "📝 Your runbook can now clean up Azure AD devices to prevent hostname conflicts." -ForegroundColor Cyan

}
catch {
    Write-Error "❌ Failed to assign permission: $($_.Exception.Message)"
    Write-Host "" -ForegroundColor White
    Write-Host "🔧 Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "1. Ensure you have Global Administrator or Privileged Role Administrator permissions" -ForegroundColor Gray
    Write-Host "2. Verify the Automation Account has system-assigned managed identity enabled" -ForegroundColor Gray
    Write-Host "3. Check that you're connected to the correct Azure tenant" -ForegroundColor Gray
    Write-Host "4. Try running the commands manually using Microsoft Graph PowerShell" -ForegroundColor Gray
    Write-Host "5. Alternative: Use Azure Portal > Azure AD > Enterprise Applications > Your Automation Account > Permissions" -ForegroundColor Gray
    exit 1
}
finally {
    # Disconnect from Microsoft Graph
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Write-Host "🔚 Disconnected from Microsoft Graph" -ForegroundColor Gray
    } catch {
        # Ignore disconnect errors
    }
}
