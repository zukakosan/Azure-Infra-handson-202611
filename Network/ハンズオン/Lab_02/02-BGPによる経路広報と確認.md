# BGPデモ：経路広報と経路伝達の観測

## 1. 目的と範囲

このパートでは、Azure VPN Gateway間のBGP経路交換と、Hubで学習した経路がSpokeへ伝達される様子を観測します。**15分の講師デモ**として実施し、受講者は画面・記録を確認するだけです。受講者によるデプロイ、設定変更、接続切り替えは行いません。

デモで確認すること：

- 2台のVPN GatewayのBGPピア状態とASN
- Gatewayが広告・学習するプレフィックス
- Spoke VM NICの有効なルートとNext hop
- Spokeから模擬オンプレミスVMへの疎通
- 講師がSpokeの経路伝達を切り替えた前後の変化

この構成はAzure VNet同士をVPN接続し、片方のVNetを模擬オンプレミスとして扱います。物理オンプレミス機器や実サイト間VPNを構築する演習ではありません。Azure FirewallやAzure Route Serverを使う構成でもありません。

## 2. デモ構成

```text
デモ用Spoke VNet
10.200.0.0/16
  VM 10.200.1.4
  ルートテーブル：Gateway route propagation 有効
        │
        │ VNet Peering（Spoke側: Use remote gateways）
        │ Gateway Transit（Hub側: Allow gateway transit）
        ▼
BGP Hub VNet 10.100.0.0/16 ── VPN Gateway (ASN 65010)
                                      ║
                          VNet-to-VNet VPN / BGP
                          双方向接続でBGP有効
                                      ║
模擬オンプレミス VNet 10.120.0.0/16 ── VPN Gateway (ASN 65020)
  VM 10.120.1.4
```

| リソース | 名前の例 | アドレス／設定 |
|---|---|---|
| BGP Hub VNet | `vnet-bgp-demo-hub` | `10.100.0.0/16` |
| Hub GatewaySubnet / VPN Gateway | `10.100.255.0/27` / `vgw-bgp-demo-hub` | Route-based、`VpnGw1`、BGP ASN `65010` |
| デモ用Spoke VNet / VMサブネット | `vnet-bgp-demo-spoke` / `snet-vm` | `10.200.0.0/16` / `10.200.1.0/24` |
| デモ用Spoke VM / ルートテーブル | `vm-bgp-demo-spoke` / `rt-bgp-demo-spoke` | `10.200.1.4` / Gateway route propagation 有効 |
| デモ用Spoke Bastion | `bas-bgp-demo-spoke` | Bastion Developer。VMに公開IPなし |
| 模擬オンプレミスVNet | `vnet-bgp-demo-onprem` | `10.120.0.0/16` |
| 模擬側GatewaySubnet / VPN Gateway | `10.120.255.0/27` / `vgw-bgp-demo-onprem` | Route-based、`VpnGw1`、BGP ASN `65020` |
| 模擬側VMサブネット / VM | `10.120.1.0/24` / `vm-bgp-demo-onprem` | VM `10.120.1.4` |
| 模擬側Bastion | `bas-bgp-demo-onprem` | Bastion Developer。VMに公開IPなし |
| VPN接続 | `conn-bgp-demo-hub-to-onprem`、`conn-bgp-demo-onprem-to-hub` | VNet-to-VNetの双方向接続。両方でBGP有効 |
| Hub–Spokeピアリング | `hub-to-bgp-demo-spoke`、`bgp-demo-spoke-to-hub` | Hub側Gateway Transit、Spoke側Remote Gateway |

アドレスは既定値です。デプロイ前にSpoke、Hub、模擬側、組織ネットワークのCIDRが重複していないことを確認してください。変更時は[BGPデモ用Bicep](./bicep/README.md)のパラメーターを使い、`GatewaySubnet`を `/27` 未満にせず、Gateway subnetへNSGやUDRを関連付けないでください。

## 3. 開始条件と操作範囲

講師は専用リソースグループへ[BGPデモ用Bicep](./bicep/README.md)を事前展開し、正常状態の確認・記録を完了しておきます。受講者はBGPデモ用リソースに読み取り権限でアクセスします。Firewall演習用VNetとは接続せず、演習用RG・Gateway・VPN接続を共有しません。

| 対象 | 講師 | 受講者 |
|---|---|---|
| BGP環境のデプロイ、接続設定、復元、削除 | 実施 | 実施しない |
| BGP Gateway・VPN接続・VNet peering・ルートテーブル | 変更・操作 | 読み取り・観測のみ |
| GatewayのBGPピア、広告・学習経路 | 画面表示・切り替え | 観測・記録 |
| VMの疎通試験 | 実施 | 結果を観測・記録 |
| Firewall演習環境 | BGP環境と分離して管理 | 別の演習で操作 |

デモ中に状態が想定と異なる場合は、その場で別設定を試さず、観測結果を記録して講師が確認します。VPNの共有キーや資格情報を表示・記録しません。

## 4. 15分の講師デモ

### 0–3分：構成と試験条件

1. 図でHub、Spoke、模擬オンプレミス、Gateway、VPN接続、Gateway Transitの役割を説明する。
2. 受講者へ「Spoke VM `10.200.1.4`から模擬側VM `10.120.1.4`への通信」を示す。
3. Hub–模擬側のVNet-to-VNet接続があり、直接VNetピアリングではないことを確認する。

### 3–7分：BGPピアと広告・学習経路

1. Hub VPN Gatewayの「BGP peers」でピア状態とASNを表示する。Hub ASNは`65010`、模擬側ASNは`65020`。
2. Hub Gatewayの広告・学習経路を表示し、どちらが広告元でどちらが受信側かを区別して説明する。
3. 模擬側Gatewayでも同様に表示する。模擬側プレフィックスとHub／Spoke側プレフィックスを、実際に表示された値で記録する。

「Gatewayが広告した経路」「Gatewayが学習した経路」「VM NICへ適用された有効ルート」は別の観測結果です。Next hopの表示だけでBGP経路だと判断せず、プレフィックスと画面上の由来を照合します。

### 7–11分：Spokeへの経路伝達と疎通

1. Hub側peeringの`Allow gateway transit`、Spoke側peeringの`Use remote gateways`、両方向peeringの`Allow forwarded traffic`、SpokeルートテーブルのGateway route propagationが有効であることを表示する。
2. Spoke VM NICの有効なルートで、模擬側宛てのプレフィックス、状態、由来、Next hopを確認する。
3. Spoke VMから模擬側VMへpingを実施し、時刻・応答数・損失率を記録する。NSGとゲストOSでも試験するICMPが許可されていることを確認する。

### 11–14分：経路伝達の切り替えをデモ

1. 切り替え前のBGPピア状態、Gatewayの広告・学習ルート、Spoke NICの有効ルート、ping結果を記録する。
2. 講師が`rt-bgp-demo-spoke`のGateway route propagationを一時的に無効化し、反映後に同じ観測を繰り返す。
3. BGPピア状態・Gatewayの広告／学習経路と、Spoke NICの有効ルート・疎通を比較する。経路伝達の変更がBGPセッション自体を切断するとは限らない。
4. Gateway route propagationを有効へ戻し、基準状態への復元を確認する。

経路やpingが必ず消えると決めつけず、実機で観測した結果を説明します。想定外の状態や復元失敗があれば、追加変更をせずデモを中断して原因を確認してください。

### 14–15分：要点の整理

- BGPピアが確立していること、経路が広告・学習されていること、Spoke NICへ経路が適用されていることは別々に確認する。
- Gateway TransitとSpoke側のRemote Gateway設定が、Gateway経由の経路利用に関わる。
- 片方向の経路だけでなく、応答側の経路と実通信も合わせて確認する。
- BGP環境は講師が管理し、受講者は観測のみとする。

## 5. 記録表

| 観測対象 | 切り替え前 | 経路伝達を無効化 | 復元後 |
|---|---|---|---|
| Hub／模擬側GatewayのBGPピア状態 |  |  |  |
| Hub Gatewayの広告・学習プレフィックス |  |  |  |
| 模擬側Gatewayの広告・学習プレフィックス |  |  |  |
| Spoke NICの模擬側宛て有効ルート・Next hop |  |  |  |
| Spoke VM → 模擬側VM ping（時刻・応答・損失） |  |  |  |
| 変化した点／維持された点 |  |  |  |

## 6. 参考資料

- [BGPデモ用Bicepと事前展開手順](./bicep/README.md)
- [Azure VPN GatewayでBGPを構成する](https://learn.microsoft.com/azure/vpn-gateway/configure-bgp)
- [VPN Gateway FAQ：BGPとルーティング](https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-vpn-faq#bgp-and-routing)
- [Azure Bastion Developerのデプロイ](https://learn.microsoft.com/azure/bastion/quickstart-host-portal#deploy-bastion)
