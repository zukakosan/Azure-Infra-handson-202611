targetScope = 'subscription'

@description('Unique demo identifier: lowercase letters and digits, starting with a letter. Use a new identifier for a new environment.')
@minLength(1)
@maxLength(16)
param demoId string

@description('Region supporting Bastion Developer, the Ubuntu image, VM size, and Azure Backup.')
param location string = 'japaneast'

@description('Ubuntu administrator password. Supply securely via environment variable; never commit it.')
@secure()
@minLength(12)
@maxLength(123)
param adminPassword string

@description('Ubuntu administrator username.')
@minLength(1)
@maxLength(32)
param adminUsername string = 'azureuser'

@description('Available VM size supporting Trusted Launch. Reserve capacity/quota for two additional restored VMs.')
param vmSize string = 'Standard_D2s_v5'

@description('Ubuntu 22.04 LTS Gen2 image version. Pin a rehearsed version for reproducibility.')
param imageVersion string = 'latest'

var tags = {
  workload: 'azure-backup-demo'
  environment: 'demo'
  demoId: demoId
}

resource sourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-backup-demo-source-${demoId}'
  location: location
  tags: tags
}

resource restoreGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-backup-demo-restore-${demoId}'
  location: location
  tags: tags
}

module sourceNetwork './modules/network.bicep' = {
  name: 'backup-demo-source-network-${demoId}'
  scope: sourceGroup
  params: {
    location: location
    suffix: 'source-${demoId}'
    addressPrefix: '10.40.0.0/16'
    subnetPrefix: '10.40.1.0/24'
    tags: tags
  }
}

module restoreNetwork './modules/network.bicep' = {
  name: 'backup-demo-restore-network-${demoId}'
  scope: restoreGroup
  params: {
    location: location
    suffix: 'restore-${demoId}'
    addressPrefix: '10.50.0.0/16'
    subnetPrefix: '10.50.1.0/24'
    tags: tags
  }
}

module sourceVm './modules/source-vm.bicep' = {
  name: 'backup-demo-source-vm-${demoId}'
  scope: sourceGroup
  params: {
    location: location
    demoId: demoId
    subnetId: sourceNetwork.outputs.subnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: vmSize
    imageVersion: imageVersion
    tags: tags
  }
}

module backup './modules/backup.bicep' = {
  name: 'backup-demo-protection-${demoId}'
  scope: sourceGroup
  params: {
    location: location
    demoId: demoId
    vmName: sourceVm.outputs.vmName
    vmId: sourceVm.outputs.vmId
    tags: tags
  }
}

module restoreSupport './modules/restore-support.bicep' = {
  name: 'backup-demo-restore-support-${demoId}'
  scope: restoreGroup
  params: {
    location: location
    demoId: demoId
    vaultPrincipalId: backup.outputs.vaultPrincipalId
    tags: tags
  }
}

output sourceResourceGroupName string = sourceGroup.name
output restoreResourceGroupName string = restoreGroup.name
output sourceVmId string = sourceVm.outputs.vmId
output sourceVmName string = sourceVm.outputs.vmName
output sourcePageUrl string = 'http://${sourceVm.outputs.publicIpAddress}/'
output sourceVmPortalUrl string = 'https://portal.azure.com/#resource${sourceVm.outputs.vmId}/overview'
output sourceBastionId string = sourceNetwork.outputs.bastionId
output restoreBastionId string = restoreNetwork.outputs.bastionId
output restoreVnetId string = restoreNetwork.outputs.vnetId
output restoreSubnetId string = restoreNetwork.outputs.subnetId
output vaultId string = backup.outputs.vaultId
output vaultName string = backup.outputs.vaultName
output backupPolicyId string = backup.outputs.policyId
output protectedItemId string = backup.outputs.protectedItemId
output stagingStorageAccountName string = restoreSupport.outputs.storageAccountName
output stagingStorageAccountId string = restoreSupport.outputs.storageAccountId
output rehearsalPublicIpId string = restoreSupport.outputs.rehearsalPublicIpId
output livePublicIpId string = restoreSupport.outputs.livePublicIpId
output rehearsalVmName string = 'vm-backup-demo-rehearsal-${demoId}'
output liveVmName string = 'vm-backup-demo-live-${demoId}'
