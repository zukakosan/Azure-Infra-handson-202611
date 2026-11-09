# IaaS 01：Bicepデプロイ結果の確認

[前へ](../../../ハンズオン/01-IaaS-ASRによるDRハンズオン.md) | [全体・進捗チェック](../../../ハンズオン/01-IaaS-ASRによるDRハンズオン.md) | [次へ](./02-configure-apache.md)

> 現在位置：1 / 8。このページの到達点：Bicepで作成した元VMへBastion Developer経由でログインできる。

初期リソースは[00：Bicepによる初期リソースの作成](../preparation/00-create-initial-resources.md)で展開します。このページではリソースを作成・変更せず、展開結果を確認します。

## Step 1：デプロイ結果を確認する

デプロイ出力またはAzure Portalで、次の項目を確認します。名前は自分の`exerciseId`に読み替えてください。

| 確認対象 | デプロイ結果 |
|---|---|
| リソースグループ | `rg-bcdr-src-<演習ID>`、`rg-bcdr-dr-<演習ID>`、`rg-bcdr-test-<演習ID>` |
| VNet・サブネット | `vnet-bcdr-src/dr/test-<演習ID>`。アドレス範囲は`10.10.0.0/16`、`10.20.0.0/16`、`10.30.0.0/16`。各VNetに`subnet-web`（各`/24`） |
| NSG | 各VNetの`subnet-web`にNSGが関連付いている。SSHはVirtualNetworkと`168.63.129.16/32`のみ許可、その他は拒否。HTTP 80は演習用 |
| Bastion | 各VNetにSKU `Developer`。有料SKUへ変更しない |
| 元VM | `vm-bcdr-src-<演習ID>`、Region A、Ubuntu 22.04 Gen2、Trusted Launch |
| 公開IP | VMのNICに演習用Standard IPv4が関連付いている |
| コンテナー | `rsv-bcdr-<演習ID>`、Region B |

NSG規則名は`Allow-Ssh-From-VirtualNetwork`、`Allow-Ssh-From-Platform`、`Allow-Http-For-Lab`、`Deny-Other-Ssh`です。公開ページに秘密情報や業務データを置かないでください。

Bicepはネットワーク、VM、コンテナー、キャッシュストレージを作成しますが、Apache・HTML・ASR複製は構成しません。送信接続は公開IPを利用します。通信エラー時にNSGを全開放して回避しません。

## Step 2：元VMへ接続する

1. デプロイ出力の`sourceVmPortalUrl`を開きます。
2. VMが実行中で、Region A・VM名・NIC・公開IP・サブネットNSGが想定どおりであることを確認します。
3. **接続 → Bastion**からSKU `Developer`を選び、ユーザー名`azureuser`とBicepで設定した演習専用パスワードで接続します。公開IPへSSH接続しません。
> ポップアップ ブロックが表示される場合には、許可してください。
4. 接続先VM名とプライベートIPを確認します。Bastionでは同時に1接続とし、別VMへ接続するときはセッションを閉じます。

<!-- VMのOS・カーネルがASR対応であることも[Trusted Launchの条件](https://learn.microsoft.com/ja-jp/azure/site-recovery/concepts-trusted-vm)で確認します。Secure BootとvTPMは無効にしません。VM作成画面からASRを有効にせず、[03：ASRの構成](./03-configure-asr.md)で設定します。 -->

**確認結果**：Bicepで作成した元VMへBastion Developerから接続でき、Region A・VM名・ネットワークを確認できること。

## このページの完了チェック

- [ ] Bicepで3つのリソースグループ、VNet、NSG、Bastion、コンテナー、キャッシュストレージ、元VMを展開した。
- [ ] 元VM・ネットワークを確認し、Bastion Developer経由でパスワードログインできた。

完了したら[全体ページ](../../../ハンズオン/01-IaaS-ASRによるDRハンズオン.md)を更新し、[02：ApacheとHTMLの構成](./02-configure-apache.md)へ進みます。

[前へ](../../../ハンズオン/01-IaaS-ASRによるDRハンズオン.md) | [全体・進捗チェック](../../../ハンズオン/01-IaaS-ASRによるDRハンズオン.md) | [次へ](./02-configure-apache.md)
