targetScope = 'resourceGroup'

@description('Region supporting Bastion Developer, the selected VM size, and Azure Firewall Standard.')
param location string = 'japaneast'

@description('Ubuntu administrator username.')
@minLength(1)
@maxLength(32)
param adminUsername string = 'azureuser'

@secure()
@description('Lab-only Ubuntu administrator password. Supply at deployment time; never store in source control.')
@minLength(12)
@maxLength(72)
param adminPassword string

@description('Generation 2 VM size available in the selected region.')
param vmSize string = 'Standard_B2s'

@description('Tags applied to all resources.')
param tags object = {
  workload: 'network-handson'
  environment: 'lab'
}

var labNodes = [
  {
    name: 'hub'
    addressPrefix: '10.0.0.0/16'
    subnetPrefix: '10.0.2.0/24'
    privateIp: '10.0.2.4'
    firewallSubnet: true
  }
  {
    name: 'spoke1'
    addressPrefix: '10.1.0.0/16'
    subnetPrefix: '10.1.1.0/24'
    privateIp: '10.1.1.4'
    firewallSubnet: false
  }
  {
    name: 'spoke2'
    addressPrefix: '10.2.0.0/16'
    subnetPrefix: '10.2.1.0/24'
    privateIp: '10.2.1.4'
    firewallSubnet: false
  }
]

var labVmIps = [for node in labNodes: node.privateIp]

module networks './modules/lab-network.bicep' = [for node in labNodes: {
  name: 'lab-${node.name}'
  params: {
    location: location
    nodeName: node.name
    addressPrefix: node.addressPrefix
    subnetPrefix: node.subnetPrefix
    privateIp: node.privateIp
    includeFirewallSubnet: node.firewallSubnet
    labVmIps: labVmIps
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: vmSize
    tags: tags
  }
}]

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-nw'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    features: {
      disableLocalAuth: true
    }
  }
}

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' = {
  name: 'fw-policy-hub'
  location: location
  tags: tags
  properties: {
    sku: {
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
    snat: {
      privateRanges: [
        'IANAPrivateRanges'
      ]
    }
  }
}

resource icmpRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: firewallPolicy
  name: 'rcg-lab'
  properties: {
    priority: 200
    ruleCollections: [
      {
        name: 'allow-lab-icmp'
        priority: 200
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'allow-icmp-between-lab-vms'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'ICMP'
            ]
            sourceAddresses: labVmIps
            destinationAddresses: labVmIps
            destinationPorts: [
              '*'
            ]
          }
        ]
      }
    ]
  }
}

resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-fw-hub'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' = {
  name: 'fw-hub'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    firewallPolicy: {
      id: firewallPolicy.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig-fw'
        properties: {
          subnet: {
            id: networks[0].outputs.firewallSubnetId
          }
          publicIPAddress: {
            id: firewallPublicIp.id
          }
        }
      }
    ]
  }
}

resource firewallDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'network-rules-to-law'
  scope: firewall
  properties: {
    workspaceId: workspace.id
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        category: 'AzureFirewallNetworkRule'
        enabled: true
      }
    ]
  }
}

output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallId string = firewall.id
output logAnalyticsWorkspaceId string = workspace.id
output vmInventory array = [for (node, i) in labNodes: {
  name: 'vm-${node.name}'
  privateIp: node.privateIp
  vmId: networks[i].outputs.vmId
  nicId: networks[i].outputs.nicId
  vnetId: networks[i].outputs.vnetId
  bastionId: networks[i].outputs.bastionId
}]
