# IaaS 01：Bicep デプロイ結果の確認

[前へ](../../../ハンズオン/01-IaaS-ASRによるDRハンズオン.md) | [全体・進捗チェック](../../../ハンズオン/01-IaaS-ASRによるDRハンズオン.md) | [次へ](./02-configure-apache.md)

> 現在位置：1 / 8。このページの到達点：Bicep で作成した元 VM へ Bastion Developer 経由でログインできる。

初期リソースは、事前準備の [00：Bicep による初期リソースの作成](../preparation/00-create-initial-resources.md)で作成済みです。このページでは、作成結果と元 VM への接続を確認します。

## Step 1：デプロイ結果を確認する

デプロイ出力または Azure Portal で、次の項目を確認します。名前は自分の `exerciseId` に読み替えてください。

| 確認対象 | デプロイ結果 |
|---|---|
| リソースグループ | `rg-bcdr-src-<演習ID>`、`rg-bcdr-dr-<演習ID>`、`rg-bcdr-test-<演習ID>` |
| VNet・サブネット | 元・DR・テスト用の `vnet-bcdr-src/dr/test-<演習ID>` と、各 VNet の `subnet-web`（各 `/24`） |
| NSG | 各 VNet の `subnet-web` に NSG が関連付いている |
| Bastion | 各 VNet に SKU `Developer` |
| 元 VM | `vm-bcdr-src-<演習ID>`、Region A、Ubuntu 22.04 Gen2、Trusted Launch |
| 公開 IP | VM の NIC に演習用 Standard IPv4 が関連付いている |
| コンテナー | `rsv-bcdr-<演習ID>`、Region B |

各 VNet のアドレス範囲は、元が `10.10.0.0/16`、DR 用が `10.20.0.0/16`、テスト用が `10.30.0.0/16` です。

> [!IMPORTANT]
> SSH は `VirtualNetwork` と `168.63.129.16/32` からのみ許可し、その他は拒否します。HTTP 80 は演習用です。

参考：NSG 規則名は `Allow-Ssh-From-VirtualNetwork`、`Allow-Ssh-From-Platform`、`Allow-Http-For-Lab`、`Deny-Other-Ssh` です。

Bicep はネットワーク、VM、コンテナー、キャッシュストレージを作成します。Apache・HTML・ASR 複製は後続の演習で構成します。VM の送信接続には公開 IP を利用します。

> [!CAUTION]
> Bastion は Developer SKU を使用し、有料 SKU に変更しないでください。公開ページに秘密情報や業務データを置かず、通信エラー時も NSG を全開放しないでください。

## 元 VM へ接続する

> [!IMPORTANT]
> 公開 IP への SSH 接続は行いません。Bastion では同時に 1 接続とし、別の VM へ接続する前に現在のセッションを閉じます。

1. デプロイ出力の `sourceVmPortalUrl` を開きます。
2. VM が実行中で、Region A・VM 名・NIC・公開 IP・サブネット NSG が想定どおりであることを確認します。
3. **接続 → Bastion** から SKU `Developer` を選び、ユーザー名 `azureuser` と Bicep で設定した演習専用パスワードで接続します。

   > [!TIP]
   > ポップアップがブロックされた場合は、Azure Portal のポップアップを許可してください。

4. 接続先 VM 名とプライベート IP を確認します。

<!-- VMのOS・カーネルがASR対応であることも[Trusted Launchの条件](https://learn.microsoft.com/ja-jp/azure/site-recovery/concepts-trusted-vm)で確認します。Secure BootとvTPMは無効にしません。VM作成画面からASRを有効にせず、[03：ASRの構成](./03-configure-asr.md)で設定します。 -->

**確認結果**：Bicep で作成した元 VM へ Bastion Developer から接続でき、Region A・VM 名・ネットワークを確認できること。

## このページの完了チェック

- [ ] 事前準備で作成した 3 つのリソースグループと、VNet、NSG、Bastion、コンテナー、キャッシュストレージ、元 VM を確認した。
- [ ] 元 VM・ネットワークを確認し、Bastion Developer 経由でパスワードログインできた。

完了したら[全体ページ](../../../ハンズオン/01-IaaS-ASRによるDRハンズオン.md)を更新し、[02：Apache と HTML の構成](./02-configure-apache.md)へ進みます。

[前へ](../../../ハンズオン/01-IaaS-ASRによるDRハンズオン.md) | [全体・進捗チェック](../../../ハンズオン/01-IaaS-ASRによるDRハンズオン.md) | [次へ](./02-configure-apache.md)
