using './main.bicep'

param exerciseId = 'a7k3p9'
param sourceLocation = 'japaneast'
param recoveryLocation = 'japanwest'
param adminPassword = readEnvironmentVariable('BCDR_ADMIN_PASSWORD')
