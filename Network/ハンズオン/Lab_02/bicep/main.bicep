targetScope = 'resourceGroup'

@description('Azure region supporting VPN Gateway, VM sizes, and Bastion Developer.')
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

@secure()
@description('Pre-shared key used by both VNet-to-VNet VPN connection resources.')
@minLength(16)
@maxLength(128)
param vpnSharedKey string

@description('Generation 2 VM size available in the selected region.')
param vmSize string = 'Standard_B2s'

@description('BGP Hub VNet address prefix.')
param hubAddressPrefix string = '10.100.0.0/16'

@description('BGP Hub GatewaySubnet address prefix. Must be at least /27.')
param hubGatewaySubnetPrefix string = '10.100.255.0/27'

@description('Demo Spoke VNet address prefix. Must not overlap the Hub or simulated on-premises VNet.')
param spokeAddressPrefix string = '10.200.0.0/16'

@description('Demo Spoke VM subnet address prefix.')
param spokeVmSubnetPrefix string = '10.200.1.0/24'

@description('Demo Spoke VM private IPv4 address within spokeVmSubnetPrefix.')
param spokeVmPrivateIp string = '10.200.1.4'

@description('Simulated on-premises VNet address prefix. Must not overlap the Hub or Spoke.')
param onPremAddressPrefix string = '10.120.0.0/16'

@description('Simulated on-premises GatewaySubnet address prefix. Must be at least /27.')
param onPremGatewaySubnetPrefix string = '10.120.255.0/27'

@description('Simulated on-premises VM subnet address prefix.')
param onPremVmSubnetPrefix string = '10.120.1.0/24'

@description('Simulated on-premises VM private IPv4 address within onPremVmSubnetPrefix.')
param onPremVmPrivateIp string = '10.120.1.4'

@description('BGP ASN for the Hub VPN Gateway.')
@minValue(1)
@maxValue(4294967295)
param hubAsn int = 65010

@description('BGP ASN for the simulated on-premises VPN Gateway.')
@minValue(1)
@maxValue(4294967295)
param onPremAsn int = 65020

@description('Resource tags applied to deployed resources.')
param tags object = {
  workload: 'network-handson'
  environment: 'bgp-demo'
  managedBy: 'instructor'
}

var vmNodes = [
  {
    name: 'spoke'
    subnetId: spokeVmSubnet.id
    privateIp: spokeVmPrivateIp
    peerPrefix: onPremAddressPrefix
  }
  {
    name: 'onprem'
    subnetId: onPremVmSubnet.id
    privateIp: onPremVmPrivateIp
    peerPrefix: spokeAddressPrefix
  }
]

resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-bgp-demo-hub'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubAddressPrefix
      ]
    }
  }
}

resource hubGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: hubVnet
  name: 'GatewaySubnet'
  properties: {
    addressPrefix: hubGatewaySubnetPrefix
  }
}

resource spokeVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-bgp-demo-spoke'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        spokeAddressPrefix
      ]
    }
  }
}

resource onPremVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-bgp-demo-onprem'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        onPremAddressPrefix
      ]
    }
  }
}

resource spokeNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-bgp-demo-spoke'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'allow-icmp-from-onprem'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Icmp'
          sourceAddressPrefix: onPremAddressPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: spokeVmPrivateIp
          destinationPortRange: '*'
        }
      }
      {
        name: 'allow-ssh-from-virtual-network'
        properties: {
          priority: 300
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: spokeVmPrivateIp
          destinationPortRange: '22'
        }
      }
      {
        name: 'allow-ssh-from-azure-platform'
        properties: {
          priority: 310
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '168.63.129.16/32'
          sourcePortRange: '*'
          destinationAddressPrefix: spokeVmPrivateIp
          destinationPortRange: '22'
        }
      }
      {
        name: 'deny-other-inbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource onPremNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-bgp-demo-onprem'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'allow-icmp-from-spoke'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Icmp'
          sourceAddressPrefix: spokeAddressPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: onPremVmPrivateIp
          destinationPortRange: '*'
        }
      }
      {
        name: 'allow-ssh-from-virtual-network'
        properties: {
          priority: 300
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: onPremVmPrivateIp
          destinationPortRange: '22'
        }
      }
      {
        name: 'allow-ssh-from-azure-platform'
        properties: {
          priority: 310
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '168.63.129.16/32'
          sourcePortRange: '*'
          destinationAddressPrefix: onPremVmPrivateIp
          destinationPortRange: '22'
        }
      }
      {
        name: 'deny-other-inbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource spokeRouteTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'rt-bgp-demo-spoke'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: []
  }
}

resource spokeVmSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: spokeVnet
  name: 'snet-vm'
  properties: {
    addressPrefix: spokeVmSubnetPrefix
    defaultOutboundAccess: false
    networkSecurityGroup: {
      id: spokeNsg.id
    }
    routeTable: {
      id: spokeRouteTable.id
    }
  }
}

resource onPremGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: onPremVnet
  name: 'GatewaySubnet'
  properties: {
    addressPrefix: onPremGatewaySubnetPrefix
  }
}

resource onPremVmSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: onPremVnet
  name: 'snet-vm'
  properties: {
    addressPrefix: onPremVmSubnetPrefix
    defaultOutboundAccess: false
    networkSecurityGroup: {
      id: onPremNsg.id
    }
  }
}

resource spokePeeringToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: spokeVnet
  name: 'bgp-demo-spoke-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    useRemoteGateways: true
  }
}

resource hubPeeringToSpoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: hubVnet
  name: 'hub-to-bgp-demo-spoke'
  properties: {
    remoteVirtualNetwork: {
      id: spokeVnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
  }
}

resource hubPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-bgp-demo-hub'
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

resource onPremPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-bgp-demo-onprem'
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

resource hubVpnGateway 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = {
  name: 'vgw-bgp-demo-hub'
  location: location
  tags: tags
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: true
    activeActive: false
    sku: {
      name: 'VpnGw1'
      tier: 'VpnGw1'
    }
    bgpSettings: {
      asn: hubAsn
    }
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: hubGatewaySubnet.id
          }
          publicIPAddress: {
            id: hubPublicIp.id
          }
        }
      }
    ]
  }
}

resource onPremVpnGateway 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = {
  name: 'vgw-bgp-demo-onprem'
  location: location
  tags: tags
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: true
    activeActive: false
    sku: {
      name: 'VpnGw1'
      tier: 'VpnGw1'
    }
    bgpSettings: {
      asn: onPremAsn
    }
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: onPremGatewaySubnet.id
          }
          publicIPAddress: {
            id: onPremPublicIp.id
          }
        }
      }
    ]
  }
}

resource hubToOnPremConnection 'Microsoft.Network/connections@2024-05-01' = {
  name: 'conn-bgp-demo-hub-to-onprem'
  location: location
  tags: tags
  properties: {
    connectionType: 'Vnet2Vnet'
    virtualNetworkGateway1: {
      id: hubVpnGateway.id
      properties: {}
    }
    virtualNetworkGateway2: {
      id: onPremVpnGateway.id
      properties: {}
    }
    sharedKey: vpnSharedKey
    enableBgp: true
  }
}

resource onPremToHubConnection 'Microsoft.Network/connections@2024-05-01' = {
  name: 'conn-bgp-demo-onprem-to-hub'
  location: location
  tags: tags
  properties: {
    connectionType: 'Vnet2Vnet'
    virtualNetworkGateway1: {
      id: onPremVpnGateway.id
      properties: {}
    }
    virtualNetworkGateway2: {
      id: hubVpnGateway.id
      properties: {}
    }
    sharedKey: vpnSharedKey
    enableBgp: true
  }
}

resource vmNics 'Microsoft.Network/networkInterfaces@2024-05-01' = [for node in vmNodes: {
  name: 'nic-bgp-demo-${node.name}'
  location: location
  tags: tags
  properties: {
    enableIPForwarding: false
    ipConfigurations: [
      {
        name: 'ipconfig-vm'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Static'
          privateIPAddress: node.privateIp
          subnet: {
            id: node.subnetId
          }
        }
      }
    ]
  }
}]

resource vms 'Microsoft.Compute/virtualMachines@2024-07-01' = [for (node, i) in vmNodes: {
  name: 'vm-bgp-demo-${node.name}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'vm-bgp-demo-${node.name}'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
      }
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNics[i].id
          properties: {
            primary: true
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}]

resource spokeBastion 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: 'bas-bgp-demo-spoke'
  location: location
  tags: tags
  sku: {
    name: 'Developer'
  }
  properties: {
    virtualNetwork: {
      id: spokeVnet.id
    }
  }
}

resource onPremBastion 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: 'bas-bgp-demo-onprem'
  location: location
  tags: tags
  sku: {
    name: 'Developer'
  }
  properties: {
    virtualNetwork: {
      id: onPremVnet.id
    }
  }
}

output spokeVnetId string = spokeVnet.id
output hubVpnGatewayId string = hubVpnGateway.id
output onPremVpnGatewayId string = onPremVpnGateway.id
output spokeRouteTableId string = spokeRouteTable.id
output connectionNames array = [
  hubToOnPremConnection.name
  onPremToHubConnection.name
]
output vmInventory array = [
  {
    name: vms[0].name
    privateIp: spokeVmPrivateIp
    nicId: vmNics[0].id
    bastionId: spokeBastion.id
  }
  {
    name: vms[1].name
    privateIp: onPremVmPrivateIp
    nicId: vmNics[1].id
    bastionId: onPremBastion.id
  }
]
