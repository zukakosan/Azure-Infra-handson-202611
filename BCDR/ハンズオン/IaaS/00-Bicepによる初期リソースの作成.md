# Bicepによる初期リソースの作成（任意）

[事前準備と確認ポイント](./00-事前準備と確認ポイント.md) | [全体・進捗チェック](../01-IaaS-ASRによるDRハンズオン.md) | [次へ：ApacheとHTMLの構成](./02-ApacheとHTMLの構成.md)

[初期環境のBicep](./infra/main.bicep)でリソースを作成します。新しい演習IDと専用リソースグループを使用し、既存の手作業環境へ重ねて展開しないでください。

## 作成するリソース

| 配置 | リソース |
|---|---|
| Region A（既定：東日本） | 専用元リソースグループ、元VNet・サブネット・NSG・Bastion Developer、Ubuntu Server 22.04 LTS Gen2 VM、OS管理ディスク、NIC、Standard公開IPv4、キャッシュストレージ |
| Region B（既定：西日本） | 専用DR用リソースグループ（VNet・NSG・Bastion Developer、Recovery Servicesコンテナー、再保護用キャッシュストレージ）、専用テスト用リソースグループ（VNet・NSG・Bastion Developer） |

名前・アドレス範囲は[Portal手順](./01-ネットワークとVMの作成.md)と同じです。RG名は`rg-bcdr-src-<乱数>`、`rg-bcdr-dr-<乱数>`、`rg-bcdr-test-<乱数>`の形式です。参加者・グループごとに英数字の乱数を1つ選び、全リソース名で共通使用します。3つのNSGはSSH（22）をVirtualNetwork・`168.63.129.16/32`から許可し、その他からは拒否します。ログインには各VNetのBastion Developerを使用します。HTTP（80）は演習ページ用にAnyへ許可します。VNet間接続は作成しません。

**Apache、HTML、ASRの複製有効化・ポリシー・復旧VMは作成しません。** 初期複製も始まりません。キャッシュストレージは両リージョンにStandard LRSで事前作成します。名前は`stbcdrsrc<一意文字列>`・`stbcdrdr<一意文字列>`で、グループIDから生成する一意文字列を使います。Azure RBACの割り当ては行わず、[ASR構成手順](./03-ASRの構成と初期複製.md)で参加者が付与します。

テスト用グループにはテストVNet・NSG・Bastionを分けます。ASRが作成するテストVMなどの配置先は、サービスが示すRGをPortalで確認してください。このBicepがASRのテストVM配置先まで制御するものではありません。

## 開始条件と注意

- Azure CLI、演習用サブスクリプション、サブスクリプションスコープの展開とリソース作成権限が必要です。Bicep CLIはBicepを使うコマンドの初回実行時にAzure CLIが自動インストールします。
- `exerciseId`は英小文字・数字・ハイフンの1～24文字とし、先頭・末尾は英数字にします。
- 2つのリージョンを異なる値にし、ASR対応、イメージ、VMサイズ（既定`Standard_D2s_v5`）、クォータ、ポリシーを確認します。Bicepのコンパイルだけではこれらを検証できません。
- `imageVersion`の既定は`latest`です。初回構築後にOS・カーネルのASR対応を確認し、反復開催では検証済みイメージバージョンを固定してください。
- 演習VMのパスワードは講師から別途受け取ります。以下の`<演習用パスワード>`は実際の値に置き換え、リポジトリには保存しません。他の環境・アカウントへ絶対に流用しません。Bicepでは`adminPassword`をsecure parameterとして受け渡します。接続元グローバルIPv4の指定は不要です。
- 両リージョンのBastion Developer対応を確認します。Developer用の`AzureBastionSubnet`と専用公開IPは作成しません。有料SKUへ自動変更しません。
- VMはTrusted Launchで作成し、Secure BootとvTPMを有効にします。Ubuntu 22.04のASR対応は[公式条件](https://learn.microsoft.com/ja-jp/azure/site-recovery/concepts-trusted-vm)に従い、実際のカーネルも確認します。LinuxではVM作成時のASR有効化を使わず、後からコンテナーで設定します。Standardセキュリティ用のサブスクリプション機能登録は不要です。
- 組織が公開IPを許可する専用演習向けです。HTTP、公開IP、コンテナーの公開サービスエンドポイントを使用します。本番用のPrivate Endpoint構成ではありません。
- HTTPは暗号化・認証なしで誰でも閲覧できます。静的な演習データ以外を置かず、終了後に削除してください。HTTPS（443）は構成しません。
- コンテナーはシステム割り当てIDを有効化します。キャッシュストレージはHTTPS・TLS 1.2以上とし、匿名Blobアクセス・共有キー認証は無効です。演習の既存ネットワークから接続するため公開サービスエンドポイントを使い、Private Endpointは作成しません。複製有効化前に、両方のストレージでコンテナーのIDへ必要なロールを付与します。参加者にはロール割り当てを作成できる権限が必要です。
- サブネットの既定の送信接続は無効です。元VMは明示的な公開IPを送信にも使用します。テスト・復旧先は各演習の手順で公開IPを関連付けます。

## 1. パラメータを指定する

リポジトリルートのPowerShellで実行します。これはUbuntu VM内のコマンドではありません。

```powershell
az login
az account set --subscription '<演習用サブスクリプションID>'
if ($LASTEXITCODE -ne 0) { throw 'Subscription selection failed.' }

$env:BCDR_ADMIN_PASSWORD = '<演習用パスワード>'
```

`<演習用パスワード>`は、英大文字・英小文字・数字・記号を含む12～123文字の実際のパスワードに置き換えます。上記の`$env:BCDR_ADMIN_PASSWORD = '...'`が環境変数の設定コマンドです。この値はリポジトリへ保存・公開せず、演習専用VM以外へ使用しないでください。`main.bicep`のsecure parameterとしてAzureへ渡します。

**環境変数の設定と、以降のビルド・デプロイは同じPowerShellターミナルで実行してください。** この設定は現在のPowerShellプロセス内だけで有効です。ターミナルを開き直した場合は再設定します。値を表示せずに設定済みか確認するには、次を実行します。

```powershell
Test-Path Env:BCDR_ADMIN_PASSWORD
```

`True`なら設定されています。`False`なら設定コマンドを実行してください。環境変数の値は平文として保持され、`@secure()`でも環境変数自体が暗号化されるわけではありません。デプロイ完了後は、次のコマンドで削除します。

```powershell
Remove-Item Env:BCDR_ADMIN_PASSWORD
```

[パラメータファイル](./infra/main.bicepparam)の演習ID（参加者共通の乱数）とリージョンを編集します。パスワードは環境変数からsecure parameterとして読み込みます。指定しない場合はパラメータのビルドが失敗します。

### クォータ不足時のリージョン切り替え

`sourceLocation`（Region A）と`recoveryLocation`（Region B）は既にパラメータ化されています。[パラメータファイル](./infra/main.bicepparam)と[サンプル](./infra/main-sample.bicepparam)のコメントに、[Azureの公式ペアリージョン](https://learn.microsoft.com/azure/reliability/regions-paired)の候補を記載しています。

| 候補 | `sourceLocation` | `recoveryLocation` |
|---|---|---|
| 東日本 / 西日本（既定） | `japaneast` | `japanwest` |
| 東南アジア / 東アジア | `southeastasia` | `eastasia` |
| オーストラリア東部 / 南東部 | `australiaeast` | `australiasoutheast` |
| 北ヨーロッパ / 西ヨーロッパ | `northeurope` | `westeurope` |
| 米国東部2 / 米国中部 | `eastus2` | `centralus` |

元と復旧先は逆方向でも構いません。切り替える場合は**2つの値をペアで変更**し、両リージョンで[クォータとサービス対応](./00-事前準備と確認ポイント.md#33-両リージョンのクォータとサービス対応)および組織の許可リージョンを確認します。候補は両側が[Bastion Developerの対応リージョン](https://learn.microsoft.com/azure/bastion/bastion-sku-comparison#regional-availability)に含まれる組み合わせですが、VMサイズ・イメージ・ASR対応・クォータ・実際の容量は実行前に再確認が必要です。ペアであることは、クォータや容量の確保を保証しません。

変更は初回作成前に行います。途中で切り替える場合は、[クリーンアップ](./08-クリーンアップ.md)で既存の演習環境を片付け、新しい`exerciseId`で作り直してください。パラメータ変更で作成済みリソースが別リージョンへ移動するわけではありません。以降のPortal手順にある東日本・西日本も、選択したRegion A・Bへ読み替えます。

## 2. ローカルビルドと変更内容の確認

```powershell
az bicep build --file '.\BCDR\ハンズオン\IaaS\infra\main.bicep' --stdout | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Bicep build failed.' }

az deployment sub what-if `
  --name bcdr-initial `
  --location japaneast `
  --template-file '.\BCDR\ハンズオン\IaaS\infra\main.bicep' `
  --parameters '.\BCDR\ハンズオン\IaaS\infra\main.bicepparam'
if ($LASTEXITCODE -ne 0) { throw 'Deployment what-if failed.' }
```

`--location`は展開履歴の保存先です。VMやコンテナーのリージョンはパラメータで決まります。対象の3つのグループ名、BastionのDeveloper SKU、公開IP、HTTPのAny許可、SSHの拒否規則、費用を確認します。既存リソースの変更が表示された場合は実行を止め、乱数IDを確認してください。

## 3. 承認後に展開する

以下はAzureリソースを作成し、費用が発生します。変更内容を確認してから実行してください。

```powershell
az deployment sub create `
  --name bcdr-initial `
  --location japaneast `
  --template-file '.\BCDR\ハンズオン\IaaS\infra\main.bicep' `
  --parameters '.\BCDR\ハンズオン\IaaS\infra\main.bicepparam' `
  --query properties.outputs --output json
if ($LASTEXITCODE -ne 0) { throw 'Deployment failed. Inspect deployment operations before retrying.' }
```

出力された3つのRG名、VM ID、公開IP、各Bastion ID、サブネットID、コンテナーIDと、`sourceCacheStorageAccountName`・`recoveryCacheStorageAccountName`を手元の任意のメモに控えます。キャッシュストレージは前者がRegion A、後者がRegion Bです。`sourcePageUrl`はApache設定後に利用するURLであり、展開直後はWeb応答しません。`sourceVmPortalUrl`を開き、**接続 → Bastion** で`azureuser`と入力したパスワードを使用します。詳しくは[Portal手順の1.4](./01-ネットワークとVMの作成.md)を参照します。公開IPへSSH接続はしません。

## 4. ハンズオンへ戻る

- [ ] VM・3つのVNet・NSG・Bastion Developer・コンテナー・両リージョンのキャッシュストレージの展開が成功した。
- [ ] 元VMへBastion Developer経由でパスワードログインできた。
- [ ] OS・カーネル・ディスク・リージョンを確認し、リソース情報を記録した。
- [ ] Apache未導入・ASR複製未有効の状態であることを理解した。

全体の進捗チェックの「01」を完了とし、[02：ApacheとHTMLの構成](./02-ApacheとHTMLの構成.md)へ進みます。その後、[03：ASRの構成と初期複製](./03-ASRの構成と初期複製.md)では既存のコンテナーを開き、作成をスキップしてレプリケーション有効化から実施します。

ASR演習開始後は元VM・ディスク・ネットワークが再構成されるため、**初期環境のBicepを再展開してリセットしないでください。** 初期環境を再作成する場合は、[クリーンアップ](./08-クリーンアップ.md)で保護を解除して専用環境を削除し、新しい演習として構築します。
