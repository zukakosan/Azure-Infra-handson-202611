targetScope = 'subscription'

@description('Unique lab identifier. Use lowercase letters, digits, and hyphens; start and end with a letter or digit.')
@minLength(1)
@maxLength(24)
param exerciseId string

@description('Source region supporting the selected Ubuntu image, VM size, and ASR.')
param sourceLocation string = 'japaneast'

@description('Recovery region. Must differ from sourceLocation and support the selected VM size and ASR.')
param recoveryLocation string = 'japanwest'

@description('Initial Ubuntu administrator password. Use 12-123 characters including uppercase, lowercase, digit, and special character. Supply securely; never commit it.')
@secure()
@minLength(12)
@maxLength(123)
param adminPassword string

@description('Ubuntu administrator username.')
@minLength(1)
@maxLength(32)
param adminUsername string = 'azureuser'

@description('VM size available in both regions. Confirm quota and ASR compatibility before deployment.')
param vmSize string = 'Standard_D2s_v5'

@description('Ubuntu image version. Pin a tested version for repeatable workshops; latest requires OS/kernel compatibility verification.')
param imageVersion string = 'latest'

var tags = {
  workload: 'bcdr-handson'
  environment: 'lab'
  exerciseId: exerciseId
}

resource sourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-bcdr-src-${exerciseId}'
  location: sourceLocation
  tags: tags
}

resource recoveryGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-bcdr-dr-${exerciseId}'
  location: recoveryLocation
  tags: tags
}

resource testGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-bcdr-test-${exerciseId}'
  location: recoveryLocation
  tags: tags
}

module sourceNetwork './modules/network.bicep' = {
  name: 'bcdr-source-network-${exerciseId}'
  scope: sourceGroup
  params: {
    location: sourceLocation
    suffix: 'src-${exerciseId}'
    addressPrefix: '10.10.0.0/16'
    subnetPrefix: '10.10.1.0/24'
    tags: tags
  }
}

module recoveryNetwork './modules/network.bicep' = {
  name: 'bcdr-dr-network-${exerciseId}'
  scope: recoveryGroup
  params: {
    location: recoveryLocation
    suffix: 'dr-${exerciseId}'
    addressPrefix: '10.20.0.0/16'
    subnetPrefix: '10.20.1.0/24'
    tags: tags
  }
}

module testNetwork './modules/network.bicep' = {
  name: 'bcdr-test-network-${exerciseId}'
  scope: testGroup
  params: {
    location: recoveryLocation
    suffix: 'test-${exerciseId}'
    addressPrefix: '10.30.0.0/16'
    subnetPrefix: '10.30.1.0/24'
    tags: tags
  }
}

module sourceVm './modules/source-vm.bicep' = {
  name: 'bcdr-source-vm-${exerciseId}'
  scope: sourceGroup
  params: {
    location: sourceLocation
    exerciseId: exerciseId
    subnetId: sourceNetwork.outputs.subnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: vmSize
    imageVersion: imageVersion
    tags: tags
  }
}

module recoveryVault './modules/vault.bicep' = {
  name: 'bcdr-vault-${exerciseId}'
  scope: recoveryGroup
  params: {
    location: recoveryLocation
    exerciseId: exerciseId
    tags: tags
  }
}

output sourceResourceGroupName string = sourceGroup.name
output recoveryResourceGroupName string = recoveryGroup.name
output testResourceGroupName string = testGroup.name
output sourceVmId string = sourceVm.outputs.vmId
output sourcePublicIpAddress string = sourceVm.outputs.publicIpAddress
output sourcePageUrl string = 'http://${sourceVm.outputs.publicIpAddress}/'
output sourceVmPortalUrl string = 'https://portal.azure.com/#resource${sourceVm.outputs.vmId}/overview'
output sourceBastionId string = sourceNetwork.outputs.bastionId
output recoveryBastionId string = recoveryNetwork.outputs.bastionId
output testBastionId string = testNetwork.outputs.bastionId
output sourceSubnetId string = sourceNetwork.outputs.subnetId
output recoverySubnetId string = recoveryNetwork.outputs.subnetId
output testSubnetId string = testNetwork.outputs.subnetId
output recoveryVaultId string = recoveryVault.outputs.vaultId
