using './main.bicep'

param demoId = readEnvironmentVariable('BACKUP_DEMO_ID')
param location = 'japaneast'
param adminPassword = readEnvironmentVariable('BACKUP_DEMO_ADMIN_PASSWORD')
