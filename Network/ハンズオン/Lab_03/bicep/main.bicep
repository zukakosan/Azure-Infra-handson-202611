targetScope = 'resourceGroup'

@description('Region of the existing exercise 01 resources. Must match their current region.')
param location string = 'japaneast'

@description('Existing Hub-to-Spoke 1 peering name, or the name to create if none exists.')
param hubToSpoke1PeeringName string = 'hub-to-spoke1'

@description('Existing Spoke 1-to-Hub peering name, or the name to create if none exists.')
param spoke1ToHubPeeringName string = 'spoke1-to-hub'

@description('Existing Hub-to-Spoke 2 peering name, or the name to create if none exists.')
param hubToSpoke2PeeringName string = 'hub-to-spoke2'

@description('Existing Spoke 2-to-Hub peering name, or the name to create if none exists.')
param spoke2ToHubPeeringName string = 'spoke2-to-hub'

resource hub 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: 'vnet-hub'
}

resource spoke1 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: 'vnet-spoke1'
}

resource spoke2 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: 'vnet-spoke2'
}

resource spoke1Nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' existing = {
  name: 'nsg-spoke1'
}

resource spoke2Nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' existing = {
  name: 'nsg-spoke2'
}

resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' existing = {
  name: 'fw-hub'
}

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' existing = {
  name: 'fw-policy-hub'
}

var firewallPrivateIp = firewall.properties.ipConfigurations[0].properties.privateIPAddress

resource spoke1Routes 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'rt-spoke1'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'to-spoke2-via-fw'
        properties: {
          addressPrefix: '10.2.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
      {
        name: 'to-internet-via-fw'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
}

resource spoke2Routes 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'rt-spoke2'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    // An explicit empty collection also removes the route created in exercise 01.
    routes: []
  }
}

resource spoke1Subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: spoke1
  name: 'snet-vm'
  properties: {
    addressPrefix: '10.1.1.0/24'
    defaultOutboundAccess: false
    networkSecurityGroup: {
      id: spoke1Nsg.id
    }
    routeTable: {
      id: spoke1Routes.id
    }
  }
}

resource spoke2Subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: spoke2
  name: 'snet-vm'
  properties: {
    addressPrefix: '10.2.1.0/24'
    defaultOutboundAccess: false
    networkSecurityGroup: {
      id: spoke2Nsg.id
    }
    routeTable: {
      id: spoke2Routes.id
    }
  }
}

resource hubToSpoke1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: hub
  name: hubToSpoke1PeeringName
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spoke1.id
    }
  }
}

resource spoke1ToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: spoke1
  name: spoke1ToHubPeeringName
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hub.id
    }
  }
}

resource hubToSpoke2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: hub
  name: hubToSpoke2PeeringName
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spoke2.id
    }
  }
}

resource spoke2ToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: spoke2
  name: spoke2ToHubPeeringName
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hub.id
    }
  }
}

resource labRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
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
            sourceAddresses: [
              '10.0.2.4'
              '10.1.1.4'
              '10.2.1.4'
            ]
            destinationAddresses: [
              '10.0.2.4'
              '10.1.1.4'
              '10.2.1.4'
            ]
            destinationPorts: [
              '*'
            ]
          }
        ]
      }
      {
        name: 'allow-lab-https'
        priority: 300
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'allow-external-https'
            ruleType: 'ApplicationRule'
            sourceAddresses: [
              '10.1.1.4'
            ]
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            // Deliberately differs from the URL specified in the participant guide.
            targetFqdns: [
              'www.example.com'
            ]
            terminateTLS: false
          }
        ]
      }
    ]
  }
}

output firewallPrivateIp string = firewallPrivateIp
output sourceVmId string = resourceId('Microsoft.Compute/virtualMachines', 'vm-spoke1')
output destinationVmId string = resourceId('Microsoft.Compute/virtualMachines', 'vm-spoke2')
output targetUrl string = 'https://www.microsoft.com/'
