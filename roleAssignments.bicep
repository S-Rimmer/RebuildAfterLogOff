// Role assignments module for Automation Account permissions
targetScope = 'subscription'

@description('The principal ID of the Automation Account managed identity')
param automationAccountPrincipalId string

@description('The resource group name where AVD resources are located')
param avdResourceGroupName string

@description('The Log Analytics Workspace resource ID')
param logAnalyticsWorkspaceResourceId string

@description('The Key Vault resource ID')
param keyVaultResourceId string

// Built-in role definition IDs
var roleDefinitionIds = {
  Reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  Contributor: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  LogAnalyticsReader: '73c42c96-874c-492b-b04d-ab87d138a893'
  KeyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
  DesktopVirtualizationVirtualMachineContributor: 'a959dbd1-f747-45e3-8ba6-dd80f235f97c'
}

// Role assignment: Reader access at subscription level
resource readerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, automationAccountPrincipalId, roleDefinitionIds.Reader)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds.Reader)
    principalId: automationAccountPrincipalId
    principalType: 'ServicePrincipal'
    description: 'Automation Account Reader access for AVD monitoring'
  }
}

// Role assignment: Contributor access to AVD resource group
resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup(avdResourceGroupName).id, automationAccountPrincipalId, roleDefinitionIds.Contributor)
  scope: resourceGroup(avdResourceGroupName)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds.Contributor)
    principalId: automationAccountPrincipalId
    principalType: 'ServicePrincipal'
    description: 'Automation Account Contributor access to AVD resources'
  }
}

// Role assignment: Log Analytics Reader access
resource logAnalyticsReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(logAnalyticsWorkspaceResourceId, automationAccountPrincipalId, roleDefinitionIds.LogAnalyticsReader)
  scope: resourceGroup(split(logAnalyticsWorkspaceResourceId, '/')[4])
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds.LogAnalyticsReader)
    principalId: automationAccountPrincipalId
    principalType: 'ServicePrincipal'
    description: 'Automation Account Log Analytics Reader access for session monitoring'
  }
}

// Role assignment: Key Vault Secrets User access
resource keyVaultSecretsUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultResourceId, automationAccountPrincipalId, roleDefinitionIds.KeyVaultSecretsUser)
  scope: resourceGroup(split(keyVaultResourceId, '/')[4])
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds.KeyVaultSecretsUser)
    principalId: automationAccountPrincipalId
    principalType: 'ServicePrincipal'
    description: 'Automation Account Key Vault Secrets User access for VM credentials'
  }
}

// Role assignment: Desktop Virtualization Virtual Machine Contributor for AVD operations
resource avdVmContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup(avdResourceGroupName).id, automationAccountPrincipalId, roleDefinitionIds.DesktopVirtualizationVirtualMachineContributor)
  scope: resourceGroup(avdResourceGroupName)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionIds.DesktopVirtualizationVirtualMachineContributor)
    principalId: automationAccountPrincipalId
    principalType: 'ServicePrincipal'
    description: 'Automation Account AVD Virtual Machine Contributor access'
  }
}

// Outputs
output roleAssignmentIds object = {
  subscriptionReader: readerRoleAssignment.id
  avdResourceGroupContributor: contributorRoleAssignment.id
  logAnalyticsReader: logAnalyticsReaderRoleAssignment.id
  keyVaultSecretsUser: keyVaultSecretsUserRoleAssignment.id
  avdVmContributor: avdVmContributorRoleAssignment.id
}
