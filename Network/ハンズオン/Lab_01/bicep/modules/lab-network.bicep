@description('Azure region supporting Bastion Developer.')
param location string

@description('Lab node name: hub, spoke1, or spoke2.')
param nodeName string

@description('VNet IPv4 address prefix.')
param addressPrefix string

@description('VM subnet IPv4 address prefix.')
param subnetPrefix string

@description('Static VM private IPv4 address.')
param privateIp string

@description('Whether this VNet contains AzureFirewallSubnet.')
param includeFirewallSubnet bool

@description('Private IPv4 addresses of the lab VMs allowed to exchange ICMP.')
param labVmIps array

@description('Ubuntu administrator username.')
param adminUsername string

@secure()
@description('Lab-only administrator password.')
param adminPassword string

@description('Generation 2 VM size.')
param vmSize string

@description('Resource tags.')
param tags object

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${nodeName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'allow-lab-icmp'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Icmp'
          sourceAddressPrefixes: labVmIps
          sourcePortRange: '*'
          destinationAddressPrefix: privateIp
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
          destinationAddressPrefix: privateIp
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
          destinationAddressPrefix: privateIp
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

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-${nodeName}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: concat([
      {
        name: 'snet-vm'
        properties: {
          addressPrefix: subnetPrefix
          defaultOutboundAccess: false
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ], includeFirewallSubnet ? [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ] : [])
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'nic-${nodeName}'
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
          privateIPAddress: privateIp
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'snet-vm')
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-${nodeName}'
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
      computerName: 'vm-${nodeName}'
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
          id: nic.id
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
}

resource bastion 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: 'bas-${nodeName}'
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
output vmId string = vm.id
output nicId string = nic.id
output bastionId string = bastion.id
output firewallSubnetId string = includeFirewallSubnet
  ? resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'AzureFirewallSubnet')
  : ''
