@description('Recovery region, different from the source region.')
param location string

@description('Unique lab identifier.')
param exerciseId string

@description('Resource tags.')
param tags object

resource vault 'Microsoft.RecoveryServices/vaults@2024-04-01' = {
  name: 'rsv-bcdr-${exerciseId}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Standard'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

output vaultId string = vault.id
