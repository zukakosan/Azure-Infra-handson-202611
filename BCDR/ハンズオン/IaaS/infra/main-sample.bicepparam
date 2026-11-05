using './main.bicep'

param exerciseId = 'YOUR-ID'
param sourceLocation = 'japaneast'
param recoveryLocation = 'japanwest'
param adminPassword = readEnvironmentVariable('BCDR_ADMIN_PASSWORD')
