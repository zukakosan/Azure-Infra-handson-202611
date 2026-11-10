@description('Azure region.')
param location string

@description('Resource name suffix.')
param suffix string

@description('VNet IPv4 address prefix.')
param addressPrefix string

@description('Web subnet IPv4 address prefix.')
param subnetPrefix string

@description('Resource tags.')
param tags object

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-backup-demo-${suffix}'
  location: location
  tags: tags
  properties: {
    securityRules: [for rule in [
      { name: 'Allow-Ssh-From-VirtualNetwork', priority: 100, port: '22', source: 'VirtualNetwork', access: 'Allow' }
      { name: 'Allow-Ssh-From-Platform', priority: 110, port: '22', source: '168.63.129.16/32', access: 'Allow' }
      { name: 'Allow-Http-From-Any', priority: 120, port: '80', source: '*', access: 'Allow' }
      { name: 'Deny-Other-Inbound', priority: 130, port: '*', source: '*', access: 'Deny' }
    ]: {
      name: rule.name
      properties: {
        priority: rule.priority
        direction: 'Inbound'
        access: rule.access
        protocol: rule.access == 'Deny' ? '*' : 'Tcp'
        sourceAddressPrefix: rule.source
        sourcePortRange: '*'
        destinationAddressPrefix: '*'
        destinationPortRange: rule.port
      }
    }]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-backup-demo-${suffix}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [addressPrefix]
    }
    subnets: [
      {
        name: 'subnet-web'
        properties: {
          addressPrefix: subnetPrefix
          defaultOutboundAccess: false
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: 'bas-backup-demo-${suffix}'
  location: location
  tags: tags
  sku: {
    name: 'Developer'
  }
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
  }
}

output vnetId string = vnet.id
output subnetId string = '${vnet.id}/subnets/subnet-web'
output bastionId string = bastion.id
