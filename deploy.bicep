param AutomationAccountName string = 'aa-avd-check-rebuild-logoff'
param ResourceGroupName string = 'rg-eastus2-AVDLab-TESTREBUILD'
param Location string = resourceGroup().location
param LogAnalyticsWorkspaceResourceId string = '/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourcegroups/rg-eastus2-avdlab-manage/providers/microsoft.operationalinsights/workspaces/law-eastus2-avdlab'
param RunbookName string = 'AVD-CheckAndRebuildAtLogoff'
param RunbookScript string = 'AVD-CheckAndRebuildAtLogoff.ps1'
param _ArtifactsLocation string = 'https://raw.githubusercontent.com/JCoreMS/RebuildAfterLogOff/main/'
@description('SaS token if needed for script location.')
@secure()
param _ArtifactsLocationSasToken string = ''
@description('ISO 8601 timestamp used for the deployment names and the Automation runbook schedule.')
param time string = utcNow()

var varSubscriptionId = subscription().subscriptionId
var varCloudEnvironment = environment().name

var varJobScheduleParams = {
  CloudEnvironment: varCloudEnvironment
  SubscriptionId: varSubscriptionId
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
    diagnosticWorkspaceId: LogAnalyticsWorkspaceResourceId
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
        uri: '${_ArtifactsLocation}${_ArtifactsLocationSasToken}${RunbookScript}'
        version: '1.0.0.0'
      }
    ] 
    schedules: [
      {
        name: '${varScheduleName}-0'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT15M')
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
      {
        name: '${varScheduleName}-1'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT30M')
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
      {
        name: '${varScheduleName}-2'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT45M')
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
      {
        name: '${varScheduleName}-3'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT60M')
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
    ]
    skuName: 'Free'
    systemAssignedIdentity: true
  }
}
