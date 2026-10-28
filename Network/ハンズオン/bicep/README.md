# 班別ハンズオンの初期構築用Bicep

デプロイの操作手順・構成図・確認ポイントは、ハンズオン教材の[事前環境のデプロイ](../00-事前環境のデプロイ.md)にまとめています。講師または環境構築担当者が授業前に実施する作業で、ハンズオン120分には含めません。

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
- ピアリング・ルートテーブル・UDR・VPN Gateway・共用BGP環境は作成しない。
- パスワードは`NW_LAB_ADMIN_PASSWORD`から取得し、ソースや出力に保存しない。

## 利用時の注意

Firewall、VM、ディスク、公開IP、ログは課金対象です。実行前に[デプロイ手順](../00-事前環境のデプロイ.md)の前提条件と費用・削除期限を確認してください。

このBicepは初期構築用です。演習中の再展開は設定を上書きする場合があり、演習で追加したリソースを削除するリセットツールでもありません。復元・再展開・後片付けは同手順の説明に従ってください。
