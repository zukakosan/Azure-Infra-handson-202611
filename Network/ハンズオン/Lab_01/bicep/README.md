# 演習01：Hub-SpokeとUDRの初期環境を作るBicep

自分でFW演習環境を構築する場合は、[事前環境のデプロイ](../00-事前環境のデプロイ.md)に従って、自分専用のリソースグループへ展開してください。展開済み環境が配布されている場合は、再デプロイせず[開始チェック](../../00-NWハンズオンの進め方.md#5-開始チェック)へ進みます。構築作業はハンズオン130分に含めません。Firewall演習環境同士は接続せず、展開開始から削除完了まで約4時間以内を目安に利用します。このテンプレートはBGPデモ環境を作成しません。BGPは講師が別RGへ事前展開するデモ環境で扱い、受講者は観測のみを行います。

## テンプレートの構成

| ファイル | 役割 |
|---|---|
| [main.bicep](./main.bicep) | Hub・Spoke×2、Firewall Standard、Firewall Policy、Log Analytics、診断設定 |
| [modules/lab-network.bicep](./modules/lab-network.bicep) | 各VNetのNSG、VMサブネット、NIC、Ubuntu VM、Bastion Developer |
| [main.bicepparam](./main.bicepparam) | リージョン、管理ユーザー名、VMサイズ、パスワード環境変数 |

## 初期状態の仕様

- Hub `10.0.0.0/16`、Spoke 1 `10.1.0.0/16`、Spoke 2 `10.2.0.0/16`。
- Hub VM `10.0.2.4`、Spoke VM `10.1.1.4`・`10.2.1.4`。Ubuntu 24.04 LTS、ユーザー名／パスワード認証、VM公開IPなし。
- 各VNetにBastion Developer。既定リージョンは`japaneast`。対応リージョンでのみ使用し、ピアリング先への管理接続には使わない。
- 基本試験はping。NSGとFirewall Policyで演習VM間のICMPを許可し、HTTPサービスは作成しない。
- FirewallはHubの`AzureFirewallSubnet`（`10.0.1.0/24`）に配置。FW実IPはデプロイ出力から取得する。
- ピアリング・ルートテーブル・UDR・VPN Gateway・BGPデモ環境は作成しない。
- パスワードは`NW_LAB_ADMIN_PASSWORD`から取得し、ソースや出力に保存しない。

## 利用時の注意

障害解析用の開始状態は、初期構築完了後に[演習03用Bicep](../../Lab_03/bicep/README.md)で適用してください。演習01用と演習03用を同時に実行しないでください。BGPは受講者向け操作ではなく、講師が[BGPデモ用Bicep](../../Lab_02/bicep/README.md)で別RGへ事前展開する独立環境です。

Firewall、VM、ディスク、公開IP、ログは課金対象です。実行前に[デプロイ手順](../00-事前環境のデプロイ.md)の前提条件と費用・削除期限を確認してください。

このBicepは初期構築用です。演習中の再展開は設定を上書きする場合があり、演習で追加したリソースを削除するリセットツールでもありません。復元・再展開・後片付けは同手順の説明に従ってください。
