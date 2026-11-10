# Azure インフラ ハンズオン

Azureのネットワーク設計・トラブルシューティングと、事業継続／災害復旧（BCDR）を学ぶための教材リポジトリです。座学資料、ハンズオン手順、演習環境を作成するBicepを収録しています。

## はじめに

目的に応じて、次の資料から開始してください。

| テーマ | 学ぶ内容 | 最初に読む資料 |
|---|---|---|
| Network | Hub-Spoke、UDR、Azure Firewall、BGP、疎通障害の切り分け | [NWハンズオンの進め方](./Network/ハンズオン/00-NWハンズオンの進め方.md) |
| BCDR / IaaS | Azure Site Recovery（ASR）によるVMの複製、フェールオーバー、再保護、フェールバック | [IaaSハンズオン README](./BCDR/handson/iaas/README.md) |

**BCDR / IaaSの参加者は、開催前に[参加者用の事前準備](./BCDR/handson/iaas/preparation/00-participant-preparation.md)のツール準備とAzureへのログイン確認を済ませてください。** 当日は教材を取得し、Bicepで初期環境を展開します。

## 教材一覧

### Network：ルーティング設計・トラブルシューティング

- [ワークショップアジェンダ](./Network/azure-routing-workshop-agenda.md)
- [座学のゴール](./Network/座学/00-NW座学のゴール.md) / [座学資料](./Network/座学/) / [スライドの案内](./Network/座学/スライド/README.md)
- [ハンズオンの進め方](./Network/ハンズオン/00-NWハンズオンの進め方.md)
- [事前環境のデプロイ](./Network/ハンズオン/Lab_01/00-事前環境のデプロイ.md)
- [Hub-SpokeとUDRの基本演習](./Network/ハンズオン/Lab_01/01-Hub-SpokeとUDR.md)
- [BGPによる経路広報と確認（講師デモ）](./Network/ハンズオン/Lab_02/02-BGPによる経路広報と確認.md)
- [障害解析とAI活用](./Network/ハンズオン/Lab_03/03-障害解析とAI活用.md)

Networkは事前展開済み環境で進めます。BGPは講師デモ専用で、参加者は設定を変更せず観測します。環境構築が必要な場合は、事前デプロイ手順を別枠で実施してください。

### BCDR：DR設計・復旧運用

- [ワークショップアジェンダ](./BCDR/azure-dr-workshop-agenda.md)
- [座学のゴール](./BCDR/座学/00-BCDR座学のゴール.md) / [座学資料](./BCDR/座学/) / [スライドの案内](./BCDR/座学/スライド/README.md)
- [IaaSハンズオンの読み順・事前準備](./BCDR/handson/iaas/README.md)
- [Azure Backupによる別VMへの復元デモ](./BCDR/demo/01-Azure-Backupによる別VMへの復元.md)

BCDRのハンズオンはIaaSを対象とし、PaaSのDRは座学で扱います。アジェンダと一部の手順には検討段階の内容が含まれるため、実施範囲・リージョン・時間配分は講師の案内とIaaSハンズオンのREADMEで確認してください。IaaSの初期複製・再保護などの待ち時間は、操作時間とは別に必要です。

## リポジトリの構成

| フォルダー | 内容 |
|---|---|
| [Network](./Network/) | ネットワークのアジェンダ、座学、ハンズオン、環境構築用Bicep |
| [BCDR](./BCDR/) | BCDRのアジェンダ、座学、IaaSハンズオン、復元デモ |
| [template](./template/) | スライド作成用のデザイン資料・生成スクリプト |

## 演習時の注意

- 演習専用のサブスクリプション・リソースを使用し、本番環境や共有リソースを操作しないでください。
- リソースの展開・変更・削除は、対象と費用を確認し、講師の承認に従って行います。
- パスワード、認証コード、その他の秘密情報をリポジトリや共有メモへ保存しないでください。
- 終了後は各手順のクリーンアップを実施します。VMの停止だけでは、ディスク・公開IP・ASRなどの課金が残る場合があります。
