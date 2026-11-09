# Bicepによる初期リソースの作成

[事前準備と確認ポイント](./00-事前準備と確認ポイント.md) | [全体・進捗チェック](../../01-IaaS-ASRによるDRハンズオン.md) | [次へ：ApacheとHTMLの構成](../演習/02-ApacheとHTMLの構成.md)

この手順では、Bicepでハンズオンの初期環境を作成します。まず図で作成範囲を確認し、パラメータファイルの値を設定してデプロイします。既存の手作業環境には展開せず、新しい演習IDを使ってください。

## 作成するリソースと完了後の状態

```mermaid
flowchart LR
  subgraph A["Region A：元環境"]
    subgraph SRC["rg-bcdr-src-演習ID"]
      SN["VNet / サブネット / NSG"]
      SB["Bastion Developer"]
      VM["Ubuntu 22.04 VM<br/>Trusted Launch"]
      NIC["NIC"]
      PIP["Standard 公開IPv4"]
      DISK["OS管理ディスク"]
      SC["キャッシュストレージ<br/>Standard LRS"]
      SN --- SB
      SN --- NIC
      NIC --- VM
      PIP --- NIC
      VM --- DISK
    end
  end

  subgraph B["Region B：復旧環境"]
    subgraph DR["rg-bcdr-dr-演習ID"]
      DN["VNet / サブネット / NSG"]
      DB["Bastion Developer"]
      VAULT["Recovery Services<br/>コンテナー"]
      RC["キャッシュストレージ<br/>Standard LRS"]
      DN --- DB
    end
    subgraph TEST["rg-bcdr-test-演習ID"]
      TN["テスト用VNet / サブネット / NSG"]
      TB["Bastion Developer"]
      TN --- TB
    end
  end

  STATE["デプロイ完了：初期環境<br/>Apache・HTMLなし<br/>ASR複製・ポリシー・復旧VMなし<br/>VNet Peering・RBAC割り当てなし"]
  SRC -.-> STATE
  DR -.-> STATE
  TEST -.-> STATE
```

ASRの複製を有効にする操作は後続手順で行います。ASRのテストVM・復旧VMもこのデプロイでは作成されません。テスト用のリソースグループとネットワークだけを先に用意します。

## 1. どこに何を書くか

編集するのは[infra/main.bicepparam](./infra/main.bicepparam)です。[infra/main-sample.bicepparam](./infra/main-sample.bicepparam)は記入例です。`main.bicepparam`を開き、演習IDとリージョンを設定します。

```bicep
using './main.bicep'

param exerciseId = 'YOUR-ID'
param sourceLocation = 'japaneast'
param recoveryLocation = 'japanwest'
param adminPassword = readEnvironmentVariable('BCDR_ADMIN_PASSWORD')
```

| パラメーター | ここに設定する値 |
|---|---|
| `exerciseId` | 自分の演習ID。英小文字・数字・ハイフンで1～24文字、先頭と末尾は英数字。3つのリソースグループ名にも使われます |
| `sourceLocation` | 元環境のリージョンコード。既定は`japaneast` |
| `recoveryLocation` | 復旧・テスト環境のリージョンコード。既定は`japanwest`。元とは異なるリージョンを指定 |
| `adminPassword` | この行は変更しません。パスワードは次の手順で環境変数に設定します |

リージョンを変える場合は、`sourceLocation`と`recoveryLocation`をペアで変更します。例：`southeastasia`と`eastasia`。両リージョンのVMサイズ・Ubuntuイメージ・ASR・Bastion Developerの対応、クォータ、組織の許可リージョンを事前確認してください。候補は[Azureのペアリージョン](https://learn.microsoft.com/azure/reliability/regions-paired)を参照します。デプロイ履歴の保存先リージョンは、下記コマンドの`--location`で別に指定します。

VMサイズは`Standard_D2s_v5`、Ubuntuイメージバージョンは`latest`が既定値です。これらを変える場合は[infra/main.bicep](./infra/main.bicep)の`vmSize`・`imageVersion`の既定値を編集します。`latest`を使う場合は、初回構築後にOS・カーネルのASR対応を確認してください。反復開催では検証済みバージョンを指定してください。

## 2. パスワードとサブスクリプションを設定する

リポジトリのルートでPowerShellを開き、演習用サブスクリプションを選択します。パスワードは演習専用のものを使い、ファイルやリポジトリには書かないでください。

```powershell
az login
if ($LASTEXITCODE -ne 0) { throw 'Azure login failed.' }

az account set --subscription '<演習用サブスクリプションID>'
if ($LASTEXITCODE -ne 0) { throw 'Subscription selection failed.' }

$env:BCDR_ADMIN_PASSWORD = '<演習専用パスワード>'
```

パスワードは英大文字・英小文字・数字・記号を含む12～123文字にします。`main.bicepparam`の`adminPassword`は、この環境変数をBicepのsecure parameterとして読み込みます。環境変数の値自体は平文として保持されます。表示・保存・共有せず、以降のコマンドも同じPowerShellターミナルで実行してください。設定状態は値を表示せずに確認できます。

```powershell
Test-Path Env:BCDR_ADMIN_PASSWORD
```

`True`なら設定済みです。デプロイ後は環境変数を削除します。

```powershell
Remove-Item Env:BCDR_ADMIN_PASSWORD
```

## 3. ビルドして変更内容を確認する

```powershell
az bicep build --file '.\BCDR\ハンズオン\IaaS\準備\infra\main.bicep' --stdout | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Bicep build failed.' }

az deployment sub what-if `
  --name bcdr-initial `
  --location '<デプロイ履歴の保存先リージョン>' `
  --template-file '.\BCDR\ハンズオン\IaaS\準備\infra\main.bicep' `
  --parameters '.\BCDR\ハンズオン\IaaS\準備\infra\main.bicepparam'
if ($LASTEXITCODE -ne 0) { throw 'Deployment what-if failed.' }
```

`<デプロイ履歴の保存先リージョン>`を利用可能なリージョンコード（例：`japaneast`）に置き換えます。これはVMやコンテナーの配置リージョンではありません。`what-if`の結果で、演習ID、3つのリソースグループ、作成リソース、Bastion Developer、公開IPを確認します。既存リソースの変更が表示された場合は実行せず、演習IDとサブスクリプションを確認してください。

## 4. デプロイする

リソース作成により費用が発生します。事前準備と組織の承認を済ませ、`what-if`の内容を確認してから実行してください。

```powershell
az deployment sub create `
  --name bcdr-initial `
  --location '<デプロイ履歴の保存先リージョン>' `
  --template-file '.\BCDR\ハンズオン\IaaS\準備\infra\main.bicep' `
  --parameters '.\BCDR\ハンズオン\IaaS\準備\infra\main.bicepparam' `
  --query properties.outputs --output json
if ($LASTEXITCODE -ne 0) { throw 'Deployment failed. Inspect deployment operations before retrying.' }

Remove-Item Env:BCDR_ADMIN_PASSWORD
```

出力された3つのリソースグループ名、元VMのID・公開IP、Bastion ID、サブネットID、Recovery ServicesコンテナーID、両方のキャッシュストレージ名を記録します。`sourcePageUrl`はApache設定後に使います。元VMには`sourceVmPortalUrl`から開き、Azure Portalの**接続 → Bastion**で接続します。公開IPへのSSH接続はしません。出力値の確認は[01：デプロイ結果の確認](../演習/01-ネットワークとVMの作成.md)を参照してください。

## 5. 完了状態を確認して次へ進む

- [ ] 元・復旧・テスト用の3つのリソースグループと、図に示したリソースが作成された。
- [ ] 元VMへBastion Developer経由で接続できた。
- [ ] Apache・HTMLはまだなく、ASR複製もまだ有効になっていない。
- [ ] パスワードの環境変数を削除した。

初期環境は公開IPとHTTP（TCP 80）を使用し、HTTPSは構成しません。HTTPのページは誰でも閲覧できるため、静的な演習データ以外を置かず、終了後に削除してください。VNet PeeringとAzure RBACロール割り当ても作成されません。ASR複製を有効にする前に、両方のキャッシュストレージにRecovery ServicesコンテナーのマネージドIDへ必要なロールを割り当てます。詳しくは[03：ASRの構成と初期複製](../演習/03-ASRの構成と初期複製.md)を参照してください。

全体の進捗チェックの「01」を完了とし、[02：ApacheとHTMLの構成](../演習/02-ApacheとHTMLの構成.md)へ進みます。ASR演習開始後は元VM・ディスク・ネットワークが再構成されるため、このBicepを再展開してリセットしないでください。初期環境を作り直す場合は、[クリーンアップ](../演習/08-クリーンアップ.md)で専用環境を削除し、新しい演習IDで構築します。
