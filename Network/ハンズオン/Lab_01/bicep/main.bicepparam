using './main.bicep'

param location = 'japaneast'
param adminUsername = 'azureuser'
param adminPassword = readEnvironmentVariable('NW_LAB_ADMIN_PASSWORD')
param vmSize = 'Standard_B2s'
