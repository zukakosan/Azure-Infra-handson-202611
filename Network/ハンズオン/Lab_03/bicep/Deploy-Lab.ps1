[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory)]
    [string]$SubscriptionId
)

$ErrorActionPreference = 'Stop'

function Invoke-AzJson {
    param([string[]]$Arguments)

    $result = & az @Arguments --output json
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI failed: az $($Arguments -join ' ')"
    }
    return ($result | ConvertFrom-Json)
}

$account = Invoke-AzJson -Arguments @('account', 'show', '--subscription', $SubscriptionId)
Write-Host "Subscription: $($account.name) ($($account.id))"
Write-Host "Target resource group: $ResourceGroupName"

$vnets = @{}
$peerings = @{}
foreach ($name in @('hub', 'spoke1', 'spoke2')) {
    $vnet = Invoke-AzJson -Arguments @(
        'network', 'vnet', 'show', '--subscription', $SubscriptionId,
        '--resource-group', $ResourceGroupName, '--name', "vnet-$name"
    )
    $expectedPrefix = @{ hub = '10.0.0.0/16'; spoke1 = '10.1.0.0/16'; spoke2 = '10.2.0.0/16' }[$name]
    if (@($vnet.addressSpace.addressPrefixes).Count -ne 1 -or $vnet.addressSpace.addressPrefixes[0] -ne $expectedPrefix) {
        throw "Unexpected address space on vnet-$name. Only the exercise 01 layout is supported."
    }
    $vnets[$name] = $vnet
    $peerings[$name] = @(Invoke-AzJson -Arguments @(
        'network', 'vnet', 'peering', 'list', '--subscription', $SubscriptionId,
        '--resource-group', $ResourceGroupName, '--vnet-name', "vnet-$name"
    ))
}

$location = $vnets['hub'].location
foreach ($vnet in $vnets.Values) {
    if ($vnet.location -ne $location) {
        throw 'All exercise VNets must use the same region.'
    }
}

$firewall = Invoke-AzJson -Arguments @(
    'network', 'firewall', 'show', '--subscription', $SubscriptionId,
    '--resource-group', $ResourceGroupName, '--name', 'fw-hub'
)
$policy = Invoke-AzJson -Arguments @(
    'network', 'firewall', 'policy', 'show', '--subscription', $SubscriptionId,
    '--resource-group', $ResourceGroupName, '--name', 'fw-policy-hub'
)
if ($firewall.firewallPolicy.id -ine $policy.id -or $policy.basePolicy) {
    throw 'The exercise requires fw-hub with fw-policy-hub and no inherited policy.'
}
$groups = @(Invoke-AzJson -Arguments @(
    'network', 'firewall', 'policy', 'rule-collection-group', 'list', '--subscription', $SubscriptionId,
    '--resource-group', $ResourceGroupName, '--policy-name', 'fw-policy-hub'
))
if (@($groups | Where-Object { $_.name -ne 'rcg-lab' }).Count -gt 0) {
    throw 'Additional Firewall Policy rule groups exist. Use an uncustomized exercise 01 environment.'
}

$parameters = @("location=$location")
foreach ($pair in @(
    @{ Source = 'hub'; Target = 'spoke1'; Parameter = 'hubToSpoke1PeeringName'; Default = 'hub-to-spoke1' },
    @{ Source = 'spoke1'; Target = 'hub'; Parameter = 'spoke1ToHubPeeringName'; Default = 'spoke1-to-hub' },
    @{ Source = 'hub'; Target = 'spoke2'; Parameter = 'hubToSpoke2PeeringName'; Default = 'hub-to-spoke2' },
    @{ Source = 'spoke2'; Target = 'hub'; Parameter = 'spoke2ToHubPeeringName'; Default = 'spoke2-to-hub' }
)) {
    $allowedTargets = if ($pair.Source -eq 'hub') {
        @($vnets['spoke1'].id, $vnets['spoke2'].id)
    } else {
        @($vnets['hub'].id)
    }
    foreach ($peering in $peerings[$pair.Source]) {
        if ($peering.remoteVirtualNetwork.id -notin $allowedTargets) {
            throw "Unexpected peering on vnet-$($pair.Source). Remove temporary direct Spoke peerings before retrying."
        }
    }
    $matches = @($peerings[$pair.Source] | Where-Object {
        $_.remoteVirtualNetwork.id -ieq $vnets[$pair.Target].id
    })
    if ($matches.Count -gt 1) {
        throw "Multiple peerings found from $($pair.Source) to $($pair.Target)."
    }
    $peeringName = if ($matches.Count -eq 1) { $matches[0].name } else { $pair.Default }
    $parameters += "$($pair.Parameter)=$peeringName"
}

$template = Join-Path $PSScriptRoot 'main.bicep'
& az bicep build --file $template --stdout | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Bicep build failed.' }

$deploymentArguments = @(
    '--subscription', $SubscriptionId, '--resource-group', $ResourceGroupName,
    '--template-file', $template, '--parameters'
) + $parameters
& az deployment group validate @deploymentArguments --only-show-errors --output none
if ($LASTEXITCODE -ne 0) { throw 'Deployment validation failed.' }

& az deployment group what-if @deploymentArguments
if ($LASTEXITCODE -ne 0) { throw 'What-if failed.' }

if ((Read-Host 'This overwrites exercise routes and Firewall rules. Type the target resource group name to deploy') -cne $ResourceGroupName) {
    Write-Host 'Deployment skipped.'
    return
}

& az deployment group create @deploymentArguments --name 'nw-troubleshooting' --mode Incremental --output json
if ($LASTEXITCODE -ne 0) { throw 'Troubleshooting deployment failed. Inspect the deployment operations before retrying.' }

$returnTable = Invoke-AzJson -Arguments @(
    'network', 'route-table', 'show', '--subscription', $SubscriptionId,
    '--resource-group', $ResourceGroupName, '--name', 'rt-spoke2'
)
if (@($returnTable.routes).Count -ne 0) {
    throw 'The exercise route configuration was not applied. Inspect rt-spoke2 before starting.'
}
$ruleGroup = Invoke-AzJson -Arguments @(
    'network', 'firewall', 'policy', 'rule-collection-group', 'show', '--subscription', $SubscriptionId,
    '--resource-group', $ResourceGroupName, '--policy-name', 'fw-policy-hub', '--name', 'rcg-lab'
)
$httpsRules = @($ruleGroup.ruleCollections | Where-Object { $_.name -eq 'allow-lab-https' })
if ($httpsRules.Count -ne 1 -or $httpsRules[0].rules.Count -ne 1 -or
    @($httpsRules[0].rules[0].targetFqdns).Count -ne 1 -or
    $httpsRules[0].rules[0].targetFqdns[0] -ne 'www.example.com') {
    throw 'The exercise Firewall configuration was not applied. Inspect rcg-lab before starting.'
}
Write-Host 'Exercise configuration verified. Continue with the exercise 03 participant guide.'
