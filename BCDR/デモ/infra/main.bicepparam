using './main.bicep'

param demoId = readEnvironmentVariable('BACKUP_DEMO_ID')
param location = 'japaneast'
param lecturerHttpSource = readEnvironmentVariable('BACKUP_DEMO_HTTP_SOURCE')
param adminPassword = readEnvironmentVariable('BACKUP_DEMO_ADMIN_PASSWORD')
