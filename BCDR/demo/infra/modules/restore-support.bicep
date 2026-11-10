@description('Azure region matching the vault.')
param location string

@description('Unique demo identifier.')
param demoId string

@description('Recovery Services vault system-assigned managed identity principal ID.')
param vaultPrincipalId string

@description('Resource tags.')
param tags object

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'stabkd${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

// VM Restore Operator includes management and blob data actions. Its scope is only the dedicated restore RG.
var restoreRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'dfce8971-25e3-42e3-ba33-6055438e3080')

resource restoreRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, vaultPrincipalId, restoreRoleId)
  properties: {
    principalId: vaultPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: restoreRoleId
  }
}

resource publicIps 'Microsoft.Network/publicIPAddresses@2024-05-01' = [for role in ['rehearsal', 'live']: {
  name: 'pip-backup-demo-${role}-${demoId}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}]

output storageAccountId string = storage.id
output storageAccountName string = storage.name
output rehearsalPublicIpId string = publicIps[0].id
output livePublicIpId string = publicIps[1].id
