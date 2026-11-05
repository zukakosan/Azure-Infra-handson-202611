@description('Region of the VM acting as the replication source.')
param location string

@description('Cache role within the lab.')
@allowed([
  'src'
  'dr'
])
param role string

@description('Resource tags.')
param tags object

resource cache 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'stbcdr${role}${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    publicNetworkAccess: 'Enabled'
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
    }
  }
}

output storageAccountId string = cache.id
output storageAccountName string = cache.name
