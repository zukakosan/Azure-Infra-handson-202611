$ErrorActionPreference = 'Stop'
$script:deploymentScript = Join-Path $PSScriptRoot '..\ハンズオン\Lab_03\bicep\Deploy-Lab.ps1'
$tokens = $null
$parseErrors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path $script:deploymentScript), [ref]$tokens, [ref]$parseErrors
)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }

function Read-Host {
    if ($global:labTestState.Scenario -eq 'cancel') { return 'cancel' }
    return 'rg-test'
}

function az {
    $a = @($args)
    $global:labTestState.Calls.Add($a)
    $global:LASTEXITCODE = 0
    $prefix = $a[0..([Math]::Min(3, $a.Count - 1))] -join ' '
    $base = '/subscriptions/sub-test/resourceGroups/rg-test/providers/Microsoft.Network'
    $result = switch -Wildcard ($prefix) {
        'account show*' { @{ id = 'sub-test'; name = 'Test subscription' }; break }
        'network vnet show*' {
            $name = $a[[Array]::IndexOf($a, '--name') + 1]
            $node = $name.Replace('vnet-', '')
            $octet = @{ hub = 0; spoke1 = 1; spoke2 = 2 }[$node]
            @{ id = "$base/virtualNetworks/$name"; location = 'japaneast'; addressSpace = @{ addressPrefixes = @("10.$octet.0.0/16") } }
            break
        }
        'network vnet peering list*' {
            $name = $a[[Array]::IndexOf($a, '--vnet-name') + 1]
            if ($global:labTestState.Scenario -eq 'direct' -and $name -eq 'vnet-spoke1') {
                @{ name = 'direct'; remoteVirtualNetwork = @{ id = "$base/virtualNetworks/vnet-spoke2" } }
            } elseif ($global:labTestState.Scenario -eq 'existing') {
                $targets = if ($name -eq 'vnet-hub') { @('spoke1', 'spoke2') } else { @('hub') }
                foreach ($target in $targets) {
                    @{ name = "$name-custom-$target"; remoteVirtualNetwork = @{ id = "$base/virtualNetworks/vnet-$target" } }
                }
            }
            break
        }
        'network firewall show*' { @{ firewallPolicy = @{ id = "$base/firewallPolicies/fw-policy-hub" } }; break }
        'network firewall policy show*' { @{ id = "$base/firewallPolicies/fw-policy-hub" }; break }
        'network firewall policy rule-collection-group*' {
            if ($a[4] -eq 'show') {
                @{ ruleCollections = @(@{
                    name = 'allow-lab-https'
                    rules = @(@{ targetFqdns = @('www.example.com') })
                }) }
            } else {
                @{ name = $(if ($global:labTestState.Scenario -eq 'extra-policy') { 'custom' } else { 'rcg-lab' }) }
            }
            break
        }
        'network route-table show*' {
            if ($global:labTestState.Scenario -eq 'postcheck-failure') {
                @{ routes = @(@{ name = 'unexpected' }) }
            } else {
                @{ routes = @() }
            }
            break
        }
        'deployment group validate*' {
            if ($global:labTestState.Scenario -eq 'validation-failure') { $global:LASTEXITCODE = 1 }
            break
        }
        'deployment group create*' { $global:labTestState.Created = $true; break }
        'deployment group what-if*' { break }
        'bicep build*' { break }
        default { throw "Unexpected command: $($a -join ' ')" }
    }
    if ($null -ne $result) { $result | ConvertTo-Json -Depth 10 }
}

foreach ($scenario in @('initial', 'existing', 'cancel', 'direct', 'extra-policy', 'validation-failure', 'postcheck-failure')) {
    $global:labTestState = @{
        Scenario = $scenario
        Created = $false
        Calls = [System.Collections.Generic.List[object]]::new()
    }
    $failed = $false
    try {
        $null = & $script:deploymentScript -ResourceGroupName 'rg-test' -SubscriptionId 'sub-test'
    } catch {
        if ($scenario -notin @('direct', 'extra-policy', 'validation-failure', 'postcheck-failure')) { throw }
        $failed = $true
    }
    $shouldCreate = $scenario -in @('initial', 'existing', 'postcheck-failure')
    if ($global:labTestState.Created -ne $shouldCreate) { throw "Unexpected deployment behavior: $scenario" }
    if ($scenario -in @('direct', 'extra-policy', 'validation-failure', 'postcheck-failure') -and -not $failed) {
        throw "Expected an explicit failure: $scenario"
    }
    if ($scenario -eq 'existing') {
        $create = @($global:labTestState.Calls | Where-Object { $_[0..2] -join ' ' -eq 'deployment group create' })[0]
        if ('hubToSpoke1PeeringName=vnet-hub-custom-spoke1' -notin $create) {
            throw 'Existing peering name was not reused.'
        }
    }
    foreach ($call in $global:labTestState.Calls) {
        if ($call[0] -ne 'bicep' -and '--subscription' -notin $call) {
            throw 'An Azure command omitted the explicit subscription.'
        }
    }
    Write-Host "PASS: $scenario"
}
