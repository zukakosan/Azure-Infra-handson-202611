# Azure Backupデモ環境のBicep

[講師デモ手順書](../01-Azure-Backupによる別VMへの復元.md)の事前準備用です。ASRのBicepやリソースは参照・変更しません。サブスクリプションスコープで、**新しいデモ専用リソース**を作成します。

## 作成するもの

| 配置先 | リソース |
|---|---|
| `rg-backup-demo-source-<id>` | 元VNet・NSG、Bastion Developer、公開IP・NIC、Ubuntu 22.04 LTS Gen2 Trusted Launch VM |
| 同上 | Apacheと正常HTMLを構成するCustom Script拡張機能 |
| 同上 | Recovery Servicesコンテナー、Enhanced日次ポリシー、元VMのバックアップ保護設定 |
| `rg-backup-demo-restore-<id>` | 独立した復元先VNet・NSG、Bastion Developer |
| 同上 | 復元用ステージングストレージ、事前／当日復元VM用の未関連付け公開IP |
| 同上 | コンテナーのシステム割り当てマネージドIDに対するVM Restore Operatorロール割り当て |

- バックアップはUTC 17:00（日本時間翌02:00）に日次実行、日次保持30日、Instant Restoreのスナップショット保持7日です。固定日時の文字列はスケジュールの時刻を表すもので、復旧ポイントではありません。
- コンテナーはLRS、Cross Region Restore無効、Soft delete有効・14日です。イミュータビリティやResource Guardを無効化する操作は含みません。
- スナップショット用RGはAzure Backupが別途作成します。ポリシーの名前の接頭辞は`rg-backup-demo-snapshots-`、接尾辞はデモIDです。実際のRG名はバックアップ後に確認します。
- VMモジュールのApache設定完了後、バックアップ保護モジュールを実行します。ただし、**デプロイ成功だけで初回バックアップ・復旧ポイント取得が完了したとは扱いません**。
- **変更前・変更後のオンデマンドバックアップ、HTML変更、事前／当日のVM復元は手動**です。復元VMを空の新規VMとしてBicepで作成することはありません。

## デモ向けのネットワーク・認証

- OSログインはBastion経由のパスワード認証です。公開IPへのSSHは許可しません。SSHは専用VNet内とBastion Developerのプラットフォーム接続元に限定します。
- HTTPは必須パラメーター`lecturerHttpSource`で指定した講師端末のIPv4／狭いCIDRだけ許可します。それ以外の受信は拒否します。HTMLは演習専用で、秘密情報・業務データは配置しません。
- 元・復元先VNet間、およびASR・業務ネットワークとのピアリングは作成しません。
- サブネットの暗黙の送信アクセスは無効です。元VMは関連付け済みStandard公開IPで送信します。復元VMは**復元完了後に専用公開IPを関連付けてから**VMAccessによるパスワード再設定などを実施します。
- デモの簡略化のためPrivate Endpointは作成せず、コンテナーの公開サービスエンドポイントを利用します。ステージングストレージは公開エンドポイントを有効にしつつ、ファイアウォールの既定を拒否とし、信頼されたAzureサービスの例外だけ許可します。
- ストレージはHTTPS必須・TLS 1.2・匿名Blob禁止・共有キー認証禁止です。復元画面では**コンテナーのシステム割り当てマネージドID**を選択します。
- VM Restore Operatorは復元に必要な管理／Blobデータ操作を含む組み込みロールで、対象は復元専用RGだけです。組み込みロールは公式資料上プレビューのため、対象サブスクリプションで利用できることを事前確認します。利用できない場合はデプロイを止め、権限を再設計します。広い権限へ自動フォールバックしません。

組織のポリシーで公開IP・HTTP・公開サービスエンドポイント・パスワード認証が禁止されている場合は、このテンプレートのままデプロイしません。

## 前提

1. Azure CLIとBicep CLIが利用可能で、`az login`済みである。
2. 対象の演習用サブスクリプションを選択済みである。
3. 専用RGの作成・VM・ネットワーク・バックアップ設定に加え、復元用RGへの`Microsoft.Authorization/roleAssignments/write`権限がある。
4. リージョンでBastion Developer、VMサイズ、Ubuntuイメージ、Trusted Launchバックアップ・新規VM復元が対応している。
   元VMはホストでの暗号化も有効です。サブスクリプションの`Microsoft.Compute/EncryptionAtHost`機能登録とVMサイズの対応を確認します。未登録の場合は、承認済みの管理者に機能登録を依頼してからデプロイします。
5. 元VMと最大2台の復元VMのvCPUクォータ・容量、費用、削除承認を確認している。
6. デモIDは小文字英字から始まる英小文字・数字1〜16文字とし、同名の既存RG・リソースがないものを使う。

## PowerShellでのデプロイ

以下はリポジトリルートから実行します。サブスクリプションIDとHTTP送信元は実際の値へ置き換えます。`203.0.113.10/32`は説明用で、そのままでは講師端末から接続できません。企業プロキシ等を利用する場合は、ブラウザーのHTTP送信元と一致する範囲を確認してください。

### 1. 対象・入力を確認する

```powershell
az account set --subscription '<演習用サブスクリプションID>'
if ($LASTEXITCODE -ne 0) { throw 'サブスクリプション選択に失敗しました。' }
az account show --query '{name:name,id:id}' --output table
if ($LASTEXITCODE -ne 0) { throw 'アカウント確認に失敗しました。' }

$env:BACKUP_DEMO_ID = 'backupdemo01'
$env:BACKUP_DEMO_HTTP_SOURCE = '203.0.113.10/32' # 実際の講師端末の送信元へ置換

if ($env:BACKUP_DEMO_ID -notmatch '^[a-z][a-z0-9]{0,15}$') {
    throw 'デモIDは小文字英字から始まる英小文字・数字1〜16文字にしてください。'
}
$source = $env:BACKUP_DEMO_HTTP_SOURCE
$address = $null
if ($source -notmatch '^(\d{1,3}\.){3}\d{1,3}(/(2[4-9]|3[0-2]))?$' -or
    -not [System.Net.IPAddress]::TryParse(($source -split '/')[0], [ref]$address)) {
    throw 'HTTP送信元はIPv4または/24〜/32の狭いIPv4 CIDRで指定してください。'
}
```

`main.bicepparam`のリージョンは`japaneast`です。変更する場合はVM・Bastion・バックアップの対応を先に確認します。ユーザー名・サイズ・イメージバージョンの既定値は`main.bicep`を参照し、必要な値だけパラメーターファイルへ追加します。

### 2. パスワードを安全に渡し、What-ifを確認する

パスワードは12〜123文字で、Azureの複雑性条件を満たすものを使います。パラメーターファイルに書き込んだり、環境変数を画面へ出力したりしません。デバッグログも有効化しません。

```powershell
$secret = Read-Host 'デモVMの管理者パスワード' -AsSecureString
try {
    $env:BACKUP_DEMO_ADMIN_PASSWORD = [System.Net.NetworkCredential]::new('', $secret).Password
    az deployment sub what-if `
        --name "backup-demo-$env:BACKUP_DEMO_ID" `
        --location japaneast `
        --template-file '.\BCDR\デモ\infra\main.bicep' `
        --parameters '.\BCDR\デモ\infra\main.bicepparam'
    if ($LASTEXITCODE -ne 0) { throw 'What-ifに失敗しました。デプロイしません。' }
}
finally {
    Remove-Item Env:\BACKUP_DEMO_ADMIN_PASSWORD -ErrorAction SilentlyContinue
    $secret.Dispose()
}
```

What-ifが**専用の新規リソースだけを作成する**ことを確認します。既存環境の変更・削除が含まれる場合は進みません。費用・作成対象の承認後、次の操作を別途実行します。

### 3. デプロイする

```powershell
$secret = Read-Host '同じデモVMの管理者パスワード' -AsSecureString
try {
    $env:BACKUP_DEMO_ADMIN_PASSWORD = [System.Net.NetworkCredential]::new('', $secret).Password
    az deployment sub create `
        --name "backup-demo-$env:BACKUP_DEMO_ID" `
        --location japaneast `
        --template-file '.\BCDR\デモ\infra\main.bicep' `
        --parameters '.\BCDR\デモ\infra\main.bicepparam' `
        --query properties.outputs --output json
    if ($LASTEXITCODE -ne 0) { throw 'デプロイに失敗しました。ジョブとデプロイ操作の詳細を確認してください。' }
}
finally {
    Remove-Item Env:\BACKUP_DEMO_ADMIN_PASSWORD -ErrorAction SilentlyContinue
    $secret.Dispose()
}
```

## デプロイ後

1. 出力の`sourceVmPortalUrl`から元VMを開き、**拡張機能とアプリケーション → setup-backup-demo-web**の成功を確認します。失敗時は拡張機能の状態・エラー、VM内の`/var/log/azure/custom-script/handler.log`を確認します。
2. Bastionで元VMへ接続し、Apacheの`enabled`・`active`、ローカルHTTP、出力の`sourcePageUrl`からのブラウザー表示を確認します。表示は`backup-demo-good-v1`です。
3. `sha256sum /var/www/html/index.html`の結果とUTC時刻をVM外へ控えます。デプロイ済みなら手順書のApacheインストール・正常HTML再配置は不要です。
4. 出力の`vaultName`のバックアップ項目で、元VMとEnhancedポリシーを確認します。保護は設定済みなので、別のコンテナーやポリシーへ重複登録しません。
5. [講師デモ手順書の初回バックアップ](../01-Azure-Backupによる別VMへの復元.md#43-azure-backupを有効化し初回バックアップを完了する)の「今すぐバックアップ」から進み、変更前・変更後のポイントを順番に取得します。
6. 復元時は出力の`restoreResourceGroupName`・`restoreVnetId`・`restoreSubnetId`、必要な場合に`stagingStorageAccountName`を使います。復元認証は**システム割り当てマネージドID**を選び、ロールの伝播完了を確認します。
7. 事前VMは`rehearsalVmName`・`rehearsalPublicIpId`、当日VMは`liveVmName`・`livePublicIpId`を使います。公開IPはあらかじめ作成されていますが、復元VMのNICへの関連付けは手動です。
8. Ubuntuの復元後はパスワードがブロックされる場合があります。公開IPによる送信経路を確保してから、復元VMの **ヘルプ → パスワードのリセット** で既存管理者ユーザーのパスワードをVMAccess拡張機能で再設定し、成功を確認してBastionへ接続します。元VMでは実行しません。これは接続の再設定で、ApacheやHTMLの再構築ではありません。

再デプロイは復旧ポイントの復元ではありません。Custom ScriptはVM内の`/var/lib/backup-demo/initialized`があればHTMLを上書きしませんが、VM・ポリシー等の設定更新は起こり得ます。デモ途中の再デプロイは避けます。

## 検証と後片付け

ローカルでBicepを検証できます。生成ARMテンプレートはリポジトリ外へ出力します。`build-params`の生成物には入力パスワードが含まれるため、実パスワードを使って保存しません。

```powershell
az bicep build --file '.\BCDR\デモ\infra\main.bicep' `
    --outfile "$env:TEMP\backup-demo-template.json"
if ($LASTEXITCODE -ne 0) { throw 'Bicep検証に失敗しました。' }
```

Azureの容量・ポリシー・実際のバックアップ／復元はコンパイルだけでは検証できません。事前リハーサルを完走してください。

### セキュリティスキャンの例外

CheckovのARMチェックでは、Bicepをコンパイルしたテンプレートを対象にします。次のチェックはこのデモの明示的な例外です。無条件で全チェック合格とは扱わず、適用条件をリハーサル前に確認してください。

| Checkov ID | 例外の理由・補完策 |
|---|---|
| `CKV_AZURE_1`、`CKV_AZURE_178`、`CKV_AZURE_149` | 講師が選択したBastion経由のパスワード認証。秘密は環境変数から渡し、公開SSHを拒否。SSH公開鍵認証への変更は別途設計する |
| `CKV_AZURE_50` | 講師が選択したApache自動設定のためCustom Script拡張機能を使用。埋め込んだローカルスクリプトのみを実行し、外部からスクリプトを取得しない |
| `CKV_AZURE_59` | ステージングに公開サービスエンドポイントを使用。既定拒否＋信頼されたAzureサービス例外、共有キー禁止、コンテナーのマネージドIDと復元専用RGのRBACを使用 |
| `CKV_AZURE_206` | 一時的なステージング用ストレージはLRS。リージョン障害への冗長化はこの同一リージョンデモの対象外 |
| `CKV_AZURE_43` | ARMスキャナーが`uniqueString()`を含む動的な名前をそのまま検査するため。実際の命名は英小文字の`stabkd`＋13文字の`uniqueString()`で、合計19文字となり、Storageの3〜24文字の英小文字・数字制約を満たす |

終了後は[手順書のクリーンアップ](../01-Azure-Backupによる別VMへの復元.md#7-終了後のクリーンアップ)に従います。復元専用RGへのロール割り当て、未関連付け公開IP、ステージングVHD、Azure Backupが別途作成したスナップショット用RGも確認します。Soft deleteによりコンテナーがすぐ削除できない場合は、期限・管理者・後日削除日を記録し、保護機能を無効化して回避しません。

## 参考

- [Microsoft Learn：Enhancedポリシー](https://learn.microsoft.com/ja-jp/azure/backup/backup-azure-vms-enhanced-policy)
- [Microsoft Learn：VMの復元・マネージドID・復元後の手順](https://learn.microsoft.com/ja-jp/azure/backup/backup-azure-arm-restore-vms)
- [Microsoft Learn：VM Restore Operator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/compute#vm-restore-operator)
- [Microsoft Learn：Linux Custom Script拡張機能](https://learn.microsoft.com/ja-jp/azure/virtual-machines/extensions/custom-script-linux)
