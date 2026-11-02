# BGPデモ環境：Azure上でS2S VPNと経路伝達を観測する

このBicepは、Azure上でVNet-to-VNet VPNをS2S VPNの模擬環境として構成し、VPN Gateway間のBGP経路交換とSpokeへの経路伝達を講師がデモするためのものです。参加者向けのデプロイ／操作教材ではありません。講師が専用リソースグループへ事前展開・操作し、受講者は読み取りと観測のみを行います。

手順は[BGPデモ：経路広報と経路伝達の観測](../02-BGPによる経路広報と確認.md)を参照してください。

## 構成

| リソース | 内容 |
|---|---|
| Hub VNet | `10.100.0.0/16`、`GatewaySubnet 10.100.255.0/27` |
| Hub VPN Gateway | Route-based `VpnGw1`、BGP ASN `65010`、Standard Static Public IP |
| デモ用Spoke VNet | `10.200.0.0/16`、VMサブネット`10.200.1.0/24`、VM `10.200.1.4` |
| 模擬オンプレミスVNet | `10.120.0.0/16`、`GatewaySubnet 10.120.255.0/27`、VMサブネット`10.120.1.0/24`、VM `10.120.1.4` |
| 模擬側VPN Gateway | Route-based `VpnGw1`、BGP ASN `65020`、Standard Static Public IP |
| VNet-to-VNet VPN | 双方向の接続リソースを作成し、両方でBGPを有効化 |
| Gateway Transit | Hub側`allowGatewayTransit`、Spoke側`useRemoteGateways`。両方向のpeeringで転送トラフィックを許可 |
| Spoke route table | Gateway route propagationを有効化。デモで講師が切り替えて復元 |
| VM／管理接続 | Ubuntu VM 2台。VMに公開IPなし。各VMのVNet内にBastion Developer |

Hub、Spoke、模擬オンプレミスの各VNetは相互に重複しない必要があります。Firewall演習用VNetとは接続しません。BGPピアIPはGateway作成後に割り当てられるため、デプロイ前に固定値を教材へ書き込まず、Portalの実値を確認してください。

## ファイル

| ファイル | 用途 |
|---|---|
| [main.bicep](./main.bicep) | 3 VNet、VPN Gateway 2台、VPN接続、Gateway Transit、ルートテーブル、VM・NSG・Bastion Developerを作成 |
| [main.bicepparam](./main.bicepparam) | リージョン等の既定値と、環境変数から取得するsecure parameter |

## 事前確認と費用

- 必ず新規の専用リソースグループへ展開してください。Firewall演習のRG、共有ネットワーク、本番環境へは適用しません。
- `location`で指定するリージョンが`VpnGw1`、選択VMサイズ、Bastion Developerに対応することを確認してください。
- 既定CIDRが既存VNet、ピアリング先、VPN接続先、組織ネットワークと重複しないことを確認してください。変更する場合はVNetと各サブネットの範囲が包含関係にあり、サブネット間で重複しないようにします。
- `GatewaySubnet`は最低`/27`とし、NSGやUDRを関連付けません。特にGatewaySubnetへデフォルトルートを設定しないでください。
- VPN Gateway、GatewayのPublic IP、VM、ディスクは課金対象です。VPN Gatewayは起動している時間に課金されるため、授業に必要な時間だけ展開し、デモと記録が済んだら専用RGを削除してください。VM停止だけではGateway等の課金は止まりません。Bastion DeveloperのSKU自体は無料ですが、他のリソース費用は発生します。実際の価格はリージョン・契約・利用量で確認してください。
- 授業中の外向き通信には依存しません。VMに公開IPを割り当てず、SSHはVNet内から、ICMPは対向VNetからの試験だけをNSGで許可します。

## ローカル検証

リポジトリルートのPowerShellで実行します。これはローカルの構文検証であり、Azureへデプロイしません。

```powershell
az bicep build --file .\Network\ハンズオン\Lab_02\bicep\main.bicep
if ($LASTEXITCODE -ne 0) { throw 'Bicep build failed.' }
```

## 講師による事前デプロイ

デプロイ操作は講師が行います。Bicep CLI／Azure CLIを最新化し、対象リージョンとAzureのクォータ、`VpnGw1`の利用可能性、Bastion Developerの対応状況、利用予定時間を確認してください。Gatewayのプロビジョニングには時間がかかるため、授業直前のデプロイは避けます。

1. 専用の空RGを作成し、そのサブスクリプションとリージョンを確認する。
2. 次の例をリポジトリルートのPowerShellで実行し、プロセス内だけで資格情報を用意する。秘密値をコマンド引数、パラメータファイル、ソース、ログ、記録資料へ書かない。
3. 先に`validate`と`what-if`を確認し、予定外の変更がないことを確認してから`create`を実行する。デプロイ先は必ず講師専用の空RGとする。
4. BGPピア状態、広告・学習経路、Spokeの有効ルート、両方向の疎通、Bastion経由のVM接続を確認し、デモ前後の記録を準備する。
5. デモ完了後、対象RG名と全リソースを再確認し、承認された手順でRGを削除する。

```powershell
$ErrorActionPreference = 'Stop'
$rg = '<講師専用のBGPデモRG>'
$subscriptionId = '<演習用サブスクリプションID>'
$adminSecret = Read-Host 'Ubuntu admin password' -AsSecureString
$vpnSecret = Read-Host 'VPN shared key' -AsSecureString

try {
    $env:NW_BGP_ADMIN_PASSWORD = [System.Net.NetworkCredential]::new('', $adminSecret).Password
    $env:NW_BGP_VPN_SHARED_KEY = [System.Net.NetworkCredential]::new('', $vpnSecret).Password

    az account set --subscription $subscriptionId
    if ($LASTEXITCODE -ne 0) { throw 'Selecting the subscription failed.' }

    az deployment group validate `
        --resource-group $rg `
        --template-file .\Network\ハンズオン\Lab_02\bicep\main.bicep `
        --parameters .\Network\ハンズオン\Lab_02\bicep\main.bicepparam
    if ($LASTEXITCODE -ne 0) { throw 'Azure template validation failed.' }

    az deployment group what-if `
        --resource-group $rg `
        --template-file .\Network\ハンズオン\Lab_02\bicep\main.bicep `
        --parameters .\Network\ハンズオン\Lab_02\bicep\main.bicepparam
    if ($LASTEXITCODE -ne 0) { throw 'What-if failed.' }

    # After reviewing the what-if and confirming the dedicated RG, uncomment to deploy.
    # az deployment group create `
    #     --name bgp-demo `
    #     --resource-group $rg `
    #     --template-file .\Network\ハンズオン\Lab_02\bicep\main.bicep `
    #     --parameters .\Network\ハンズオン\Lab_02\bicep\main.bicepparam
    # if ($LASTEXITCODE -ne 0) { throw 'BGP demo deployment failed.' }
}
finally {
    Remove-Item Env:\NW_BGP_ADMIN_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:\NW_BGP_VPN_SHARED_KEY -ErrorAction SilentlyContinue
    $adminSecret.Dispose()
    $vpnSecret.Dispose()
}
```

`what-if`で想定外のリソース変更が出た場合は、適用せず原因を確認してください。VPN共有キーはHub側・模擬側の双方に同じsecure parameterとして渡し、VMパスワードもsecure parameterとして扱います。

## 参考資料

- [Azure VPN GatewayでBGPを構成する](https://learn.microsoft.com/azure/vpn-gateway/configure-bgp)
- [VPN Gateway FAQ：BGPとルーティング](https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-vpn-faq#bgp-and-routing)
- [Microsoft.Network virtualNetworkGateways Bicep reference](https://learn.microsoft.com/azure/templates/microsoft.network/2024-05-01/virtualnetworkgateways)
- [Microsoft.Network connections Bicep reference](https://learn.microsoft.com/azure/templates/microsoft.network/2024-05-01/connections)
- [Azure Bastion Developerのデプロイ](https://learn.microsoft.com/azure/bastion/quickstart-host-portal#deploy-bastion)
