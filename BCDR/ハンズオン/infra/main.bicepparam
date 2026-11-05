using './main.bicep'

param exerciseId = 'zukako'
param sourceLocation = 'japaneast'
param recoveryLocation = 'japanwest'
param adminPassword = readEnvironmentVariable('BCDR_ADMIN_PASSWORD')
