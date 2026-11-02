using './main.bicep'

param location = 'japaneast'
param adminUsername = 'azureuser'
param adminPassword = readEnvironmentVariable('NW_BGP_ADMIN_PASSWORD')
param vpnSharedKey = readEnvironmentVariable('NW_BGP_VPN_SHARED_KEY')
param vmSize = 'Standard_B2s'
