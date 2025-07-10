targetScope = 'subscription'

param _ArtifactsLocation string = 'https://raw.githubusercontent.com/S-Rimmer/RebuildAfterLogOff/main/'
@description('SaS token if needed for script location.')
@secure()
param _ArtifactsLocationSasToken string = ''

param AutomationAccountName string = 'aa-avd-check-rebuild-logoff'
param AVDResourceGroup string
param HostPoolName string
param IfNotUsedInHours int = 3
param KeyVaultName string
param KeyVaultVMAdmin string
param Location string = 'eastus2'
param LogAnalyticsWorkspace object = {
  Name: ''
  WorkspaceId: ''
  ResourceId: ''
}
param ResourceGroupName string
param RunbookName string = 'AVD-CheckAndRebuildAtLogoff'
param RunbookScript string = 'AVD-CheckAndRebuildAtLogoff.ps1'
param TemplateSpecResId string
param TemplateSpecVersion string
@description('ISO 8601 timestamp used for the deployment names and the Automation runbook schedule.')
param time string = utcNow()
@description('The ID of the image to use for the VM.')
param imageId string


var varJobScheduleParams = {
  CloudEnvironment: environment().name
  HostPoolName: HostPoolName
  avdRG: AVDResourceGroup
  SubscriptionId: subscription().subscriptionId
  TemplateSpecName: split(TemplateSpecResId, '/')[8]
  TemplateSpecVersion: TemplateSpecVersion
  TemplateSpecRG: split(TemplateSpecResId, '/')[4]
  KeyVaultName: KeyVaultName
  KeyVaultVMAdmin: KeyVaultVMAdmin
  WorkspaceId: LogAnalyticsWorkspace.WorkspaceId
  IfNotUsedInHrs: IfNotUsedInHours
  imageId: imageId
}
var varScheduleName = 'AVD-CheckAndRebuildAtLogoff'
var varTimeZone = varTimeZones[Location]
var varTimeZones = {
  australiacentral: 'AUS Eastern Standard Time'
  australiacentral2: 'AUS Eastern Standard Time'
  australiaeast: 'AUS Eastern Standard Time'
  australiasoutheast: 'AUS Eastern Standard Time'
  brazilsouth: 'E. South America Standard Time'
  brazilsoutheast: 'E. South America Standard Time'
  canadacentral: 'Eastern Standard Time'
  canadaeast: 'Eastern Standard Time'
  centralindia: 'India Standard Time'
  centralus: 'Central Standard Time'
  chinaeast: 'China Standard Time'
  chinaeast2: 'China Standard Time'
  chinanorth: 'China Standard Time'
  chinanorth2: 'China Standard Time'
  eastasia: 'China Standard Time'
  eastus: 'Eastern Standard Time'
  eastus2: 'Eastern Standard Time'
  francecentral: 'Central Europe Standard Time'
  francesouth: 'Central Europe Standard Time'
  germanynorth: 'Central Europe Standard Time'
  germanywestcentral: 'Central Europe Standard Time'
  japaneast: 'Tokyo Standard Time'
  japanwest: 'Tokyo Standard Time'
  jioindiacentral: 'India Standard Time'
  jioindiawest: 'India Standard Time'
  koreacentral: 'Korea Standard Time'
  koreasouth: 'Korea Standard Time'
  northcentralus: 'Central Standard Time'
  northeurope: 'GMT Standard Time'
  norwayeast: 'Central Europe Standard Time'
  norwaywest: 'Central Europe Standard Time'
  southafricanorth: 'South Africa Standard Time'
  southafricawest: 'South Africa Standard Time'
  southcentralus: 'Central Standard Time'
  southindia: 'India Standard Time'
  southeastasia: 'Singapore Standard Time'
  swedencentral: 'Central Europe Standard Time'
  switzerlandnorth: 'Central Europe Standard Time'
  switzerlandwest: 'Central Europe Standard Time'
  uaecentral: 'Arabian Standard Time'
  uaenorth: 'Arabian Standard Time'
  uksouth: 'GMT Standard Time'
  ukwest: 'GMT Standard Time'
  usdodcentral: 'Central Standard Time'
  usdodeast: 'Eastern Standard Time'
  usgovarizona: 'Mountain Standard Time'
  usgoviowa: 'Central Standard Time'
  usgovtexas: 'Central Standard Time'
  usgovvirginia: 'Eastern Standard Time'
  westcentralus: 'Mountain Standard Time'
  westeurope: 'Central Europe Standard Time'
  westindia: 'India Standard Time'
  westus: 'Pacific Standard Time'
  westus2: 'Pacific Standard Time'
  westus3: 'Mountain Standard Time'
}



module automationAccount 'carml/1.3.0/Microsoft.Automation/automationAccounts/deploy.bicep' = {
  name: 'c_AutomtnAcct-${AutomationAccountName}'
  scope: resourceGroup(ResourceGroupName)
  params: {
    diagnosticLogCategoriesToEnable: [
      'JobLogs'
      'JobStreams'
    ]
    enableDefaultTelemetry: false
    diagnosticWorkspaceId: LogAnalyticsWorkspace.ResourceId
    name: AutomationAccountName
    jobSchedules: [
      {
        parameters: varJobScheduleParams
        runbookName: RunbookName
        scheduleName: '${varScheduleName}-0'
      }
      {
        parameters: varJobScheduleParams
        runbookName: RunbookName
        scheduleName: '${varScheduleName}-1'
      }
      {
        parameters: varJobScheduleParams
        runbookName: RunbookName
        scheduleName: '${varScheduleName}-2'
      }
      {
        parameters: varJobScheduleParams
        runbookName: RunbookName
        scheduleName: '${varScheduleName}-3'
      }
    ]
    location: Location
    runbooks: [
      {
        name: RunbookName
        description: 'AVD Rebuild at logoff'
        type: 'PowerShell'
        uri: '${_ArtifactsLocation}${RunbookScript}${_ArtifactsLocationSasToken}'
        version: '1.0.0.0'
      }
    ] 
    schedules: [
      {
        name: '${varScheduleName}-0'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT30M')  // Increased to 30 minutes to allow role assignments to propagate
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
      {
        name: '${varScheduleName}-1'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT45M')  // Increased to 45 minutes
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
      {
        name: '${varScheduleName}-2'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT60M')  // Increased to 60 minutes
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
      {
        name: '${varScheduleName}-3'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT75M')  // Increased to 75 minutes
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
    ]
    skuName: 'Free'
    systemAssignedIdentity: true
    imageId: imageId
  }
}

// Deploy role assignments at subscription scope
module roleAssignments 'roleAssignments.bicep' = {
  name: 'roleAssignments-${AutomationAccountName}'
  scope: subscription()
  params: {
    automationAccountPrincipalId: automationAccount.outputs.systemAssignedPrincipalId
    avdResourceGroupName: AVDResourceGroup
    logAnalyticsWorkspaceResourceId: LogAnalyticsWorkspace.ResourceId
    keyVaultResourceId: resourceId('Microsoft.KeyVault/vaults', KeyVaultName)
  }
  dependsOn: [
    automationAccount
  ]
}

// Outputs for verification and integration
output automationAccountName string = automationAccount.outputs.name
output automationAccountResourceId string = automationAccount.outputs.resourceId
output automationAccountPrincipalId string = automationAccount.outputs.systemAssignedPrincipalId
output roleAssignments object = roleAssignments.outputs.roleAssignmentIds
output permissionsConfigured bool = true