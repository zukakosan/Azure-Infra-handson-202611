# BCDR ハンズオン：事前準備と確認ポイント

[ハンズオンの進め方](../README.md) | [次へ：Bicepによる初期リソースの作成](./00-create-initial-resources.md)

初期リソースはBicepで作成します。事前準備では、参加者のWindows PCに必要なツールを用意し、演習用Azure環境を確認します。

## 1. 必要なツールとインストール方法

ツールの導入は組織の端末管理ルールに従ってください。インストール後はターミナルを開き直します。

| ツール | 用途 | インストール方法 |
|---|---|---|
| ブラウザー（Microsoft Edgeなど） | Azure Portal、Bastion、演習ページを表示 | Windowsに付属するEdgeなど、組織で利用可能なブラウザーを使用 |
| PowerShell | 手元のPCでAzure CLIのコマンドを実行 | Windowsに付属するPowerShellをスタートメニューから起動 |
| Azure CLI | AzureへのログインとBicepのビルド・デプロイ | [Windows向けの公式手順](https://learn.microsoft.com/ja-jp/cli/azure/install-azure-cli-windows)から最新版のMSIを取得し、インストール。既存環境も同じ手順で更新 |
| Bicep CLI | Bicepファイルとパラメータファイルの処理 | Azure CLI導入後、以下のコマンドでインストール |
| Git for Windows | 教材リポジトリを取得 | [公式サイト](https://git-scm.com/downloads/win)からインストーラーを取得して実行。ZIPで教材を取得する場合は不要 |
| テキストエディター（Visual Studio Code推奨） | Bicepのパラメータファイルを編集 | [Visual Studio Code](https://code.visualstudio.com/)をインストールし、拡張機能画面でMicrosoft提供の[Bicep拡張機能](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep)を追加。既存のエディターでも可 |

### Azure CLIとBicep CLIの導入確認

手元のPowerShellで実行します。Azure PowerShell（Azモジュール）の追加インストールは不要です。

```powershell
az version
if ($LASTEXITCODE -ne 0) { throw 'Azure CLI version check failed.' }

az bicep install
if ($LASTEXITCODE -ne 0) { throw 'Bicep CLI installation failed.' }

az bicep version
if ($LASTEXITCODE -ne 0) { throw 'Bicep CLI version check failed.' }
```

それぞれのバージョンが表示されることを確認します。本手順では`.bicepparam`を使用するため、**最新版のAzure CLIとBicep CLIを使用してください**。Bicep CLIが既にインストール済みの場合は、`az bicep upgrade`で更新します。`az`が見つからない場合は、ターミナルの開き直しとAzure CLIのインストール状況を確認してください。

## 2. Azureへのログインとサブスクリプションの確認

手元のPowerShellでログインし、自分が利用する演習用サブスクリプションを選択します。

```powershell
az login
if ($LASTEXITCODE -ne 0) { throw 'Azure login failed.' }

az account set --subscription '<演習用サブスクリプションID>'
if ($LASTEXITCODE -ne 0) { throw 'Subscription selection failed.' }

az account show --query '{Name:name,SubscriptionId:id,TenantId:tenantId,State:state}' -o table
if ($LASTEXITCODE -ne 0) { throw 'Subscription lookup failed.' }
```

表示されたサブスクリプション名・ID・テナントが自分の選択と一致し、状態が`Enabled`であることを確認します。[Azure Portal](https://portal.azure.com/)でも同じディレクトリとサブスクリプションを選びます。利用権限がない場合は、アクセス可能な演習用サブスクリプションを選ぶか管理者に権限を依頼します。

## 3. Azure Portalでの事前確認

**自分が選んだ演習用サブスクリプション**で次を確認します。参加者が変更できない権限・ポリシー・ネットワーク制限は、サブスクリプション管理者へ確認します。

### 3.1. 自分の権限

**確認する場所：** サブスクリプション → 対象サブスクリプション → **アクセス制御（IAM）→ 自分のアクセス権の表示**

| 確認項目 | 必要な権限の目安 |
|---|---|
| リソースの作成・操作・削除 | サブスクリプションスコープの **共同作成者（Contributor）** |
| マネージドIDへのロール割り当て | 上記に加え、対象を含むスコープの **ユーザー アクセス管理者（User Access Administrator）** など |

- リソース操作には、リソースグループ作成、Bicepのサブスクリプションスコープのデプロイ、ASR操作を含みます。
- 演習では、両リージョンのキャッシュストレージで、Recovery ServicesコンテナーのマネージドIDに **共同作成者** と **ストレージ BLOB データ共同作成者** を割り当てます。
- **PIMを利用する場合**は、演習時に必要なロールを有効化できることも確認します。

### 3.2. リソースプロバイダーの登録

**確認する場所：** サブスクリプション → 対象サブスクリプション → **リソースプロバイダー**

次のすべてが **`Registered`（登録済み）** になっていることを確認します。

- `Microsoft.Compute`
- `Microsoft.Network`
- `Microsoft.Storage`
- `Microsoft.RecoveryServices`
- `Microsoft.Automation`

未登録のものは選択して **登録** を実行し、`Registered`になるまで待ちます。

### 3.3. 両リージョンのクォータとサービス対応

**クォータの確認場所：** Azure Portalの検索 → **クォータ → Compute**

Region A・Bそれぞれで、次の2種類のクォータに空きがあることを確認します。

| クォータ | 確認する内容 |
|---|---|
| リージョンの合計vCPU数 | 演習VMを起動できる空きがある |
| VMファミリ別vCPU数（DSv5ファミリ） | 既定の`Standard_D2s_v5`用に、VM 1台あたり **2 vCPU** の空きがある |

共有サブスクリプションでは、**参加者数とテスト・復旧VMの同時起動分**も含めて確保します。

あわせて、両リージョンで次を利用できることを確認します。

- VMサイズ：`Standard_D2s_v5`
- OS・セキュリティ：Ubuntu Server 22.04 LTS Gen2、Trusted Launch
- サービス：ASR、Bastion Developer

> クォータに空きがあっても、実際のVM容量不足で作成できない場合があります。

不足時に切り替えられるよう、[パラメータファイル](./infra/main.bicepparam)のコメントにペアリージョン候補を記載しています。初回作成前に`sourceLocation`と`recoveryLocation`をペアで変更し、変更先の両リージョンでも上記の条件と組織の許可リージョンを確認してください。詳細は[パラメータの設定手順](./00-create-initial-resources.md#1-bicep-のパラメータ編集)を参照します。

### 3.4. 組織のポリシーと通信制限

**確認先：** 対象サブスクリプションのAzure Policy割り当て、および組織のAzure・ネットワーク管理者

| 確認項目 | 演習で許可が必要な内容 |
|---|---|
| 公開IP | 公開IPの作成 |
| HTTP受信 | AnyからのTCP 80への受信 |
| 公開サービスエンドポイント | Recovery Servicesコンテナー・ストレージの公開サービスエンドポイントの利用 |
| VMからの送信通信 | Ubuntuのパッケージ配布先と[ASRが必要とする宛先](https://learn.microsoft.com/azure/site-recovery/azure-to-azure-about-networking)への送信 |

---

準備ができたら演習ID・リージョン・VMサイズ・専用パスワードを選び、[Bicepによる初期リソースの作成](./00-create-initial-resources.md)へ進みます。
