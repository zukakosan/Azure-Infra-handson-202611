@description('Azure region matching the protected VM.')
param location string

@description('Unique demo identifier.')
param demoId string

@description('Protected VM name in this resource group.')
param vmName string

@description('Protected VM resource ID. Configure Apache manually after deployment, before taking the demo recovery point.')
param vmId string

@description('Resource tags.')
param tags object

var backupTime = '2026-01-01T17:00:00Z'

resource vault 'Microsoft.RecoveryServices/vaults@2024-10-01' = {
  name: 'rsv-backup-demo-${demoId}'
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
    redundancySettings: {
      standardTierStorageRedundancy: 'LocallyRedundant'
      crossRegionRestore: 'Disabled'
    }
    securitySettings: {
      softDeleteSettings: {
        softDeleteState: 'Enabled'
        softDeleteRetentionPeriodInDays: 14
      }
    }
  }
}

resource policy 'Microsoft.RecoveryServices/vaults/backupPolicies@2024-10-01' = {
  parent: vault
  name: 'policy-backup-demo-daily'
  properties: {
    backupManagementType: 'AzureIaasVM'
    policyType: 'V2'
    timeZone: 'UTC'
    instantRpRetentionRangeInDays: 7
    instantRPDetails: {
      azureBackupRGNamePrefix: 'rg-backup-demo-snapshots-'
      azureBackupRGNameSuffix: demoId
    }
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicyV2'
      scheduleRunFrequency: 'Daily'
      dailySchedule: {
        scheduleRunTimes: [backupTime]
      }
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [backupTime]
        retentionDuration: {
          count: 30
          durationType: 'Days'
        }
      }
    }
  }
}

resource protectedVm 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2024-10-01' = {
  name: '${vault.name}/Azure/IaasVMContainer;iaasvmcontainerv2;${resourceGroup().name};${vmName}/VM;iaasvmcontainerv2;${resourceGroup().name};${vmName}'
  properties: {
    protectedItemType: 'Microsoft.Compute/virtualMachines'
    sourceResourceId: vmId
    policyId: policy.id
  }
}

output vaultId string = vault.id
output vaultName string = vault.name
output vaultPrincipalId string = vault.identity.principalId
output policyId string = policy.id
output protectedItemId string = protectedVm.id
