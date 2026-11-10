# Azure Backupデモ環境のデプロイ

ASRとは独立した講師用環境を、東日本リージョンに作成します。

| 配置先 | 作成するもの |
|---|---|
| `rg-backup-demo-source-<id>` | Ubuntu VM 1台、VNet・NSG・公開IP・NIC・Bastion Developer、Recovery Servicesコンテナー、バックアップポリシー・保護設定 |
| `rg-backup-demo-restore-<id>` | 復元先VNet・NSG・Bastion Developer、ステージングストレージ、復元VM用公開IP 2個、復元用ロール割り当て |

**Apache・正常HTMLの構成、変更前・変更後のバックアップ取得、復元VMの作成は、デプロイ後に手動で実施します。**

## 前提

- Azure CLI・Bicep CLIが利用可能で、リソース作成とロール割り当ての権限があること。
- Bastion Developer・VMサイズ（既定：`Standard_D2s_v5`）・VM Restore Operatorロールが利用できること。VMは復元分を含め最大3台です。
- 公開IP・HTTP・公開サービスエンドポイント・Bastion経由のパスワード認証が許可されていること。検証用として元VM・復元VMのHTTP（TCP 80）はAny許可です。機密情報は配置せず、SSHは引き続きBastion経由に限定します。

## 1. ログイン・入力値の設定

リポジトリルートのPowerShellで実行します。サブスクリプションIDは実際の値に置き換えてください。

デモIDは小文字英字で始まる英小文字・数字1〜16文字とし、既存リソースと重複しない値にします。

```powershell
az login --use-device-code
az account set --subscription '<演習用サブスクリプションID>'

$env:BACKUP_DEMO_ID = 'backupdemo01'
```

## 2. デプロイ

管理者パスワードは12〜123文字で、Azureの複雑性条件を満たす値を入力します。ファイルには保存しません。

```powershell
$secret = Read-Host 'デモVMの管理者パスワード' -AsSecureString
try {
    $env:BACKUP_DEMO_ADMIN_PASSWORD = [System.Net.NetworkCredential]::new('', $secret).Password
    az deployment sub create `
        --name "backup-demo-$env:BACKUP_DEMO_ID" `
        --location japaneast `
        --template-file '.\BCDR\demo\infra\main.bicep' `
        --parameters '.\BCDR\demo\infra\main.bicepparam' `
        --query properties.outputs `
        --output json
}
finally {
    Remove-Item Env:\BACKUP_DEMO_ADMIN_PASSWORD
    $secret.Dispose()
}
```

エラーが出た場合は先へ進まず、原因を解消します。デモ途中の再デプロイは避けてください。

## 3. デモ開始までの準備

1. 出力の`sourceVmPortalUrl`から元VMを開き、Bastionで接続します。既定ユーザー名は`azureuser`です。
2. [Apacheと正常HTMLの構成手順](../01-Azure-Backupによる別VMへの復元.md#42-apacheと正常なhtmlを構成する)をVM内で実行し、出力の`sourcePageUrl`をブラウザーで開いて`backup-demo-good-v1`を確認します。
3. 出力の`vaultName`のバックアップ項目から元VMの「今すぐバックアップ」を実行し、正常状態の復旧ポイント取得完了を確認します。**保護設定済みでも、バックアップ取得完了とは限りません。Apache構成前の復旧ポイントはデモに使いません。**
4. [講師デモ手順書](../01-Azure-Backupによる別VMへの復元.md)に従い、HTML変更、変更後のバックアップ取得、事前復元を実施します。

旧版の自動インストールで失敗した環境には、再デプロイだけでは`setup-backup-demo-web`拡張機能が残ります。必要なエラーログを記録し、元VMの **拡張機能とアプリケーション** から該当拡張機能を削除してから、手動構成を進めてください。VMの作り直しは不要です。

復元には出力の`restoreResourceGroupName`・`restoreVnetId`・`restoreSubnetId`と、必要に応じて`stagingStorageAccountName`を使用し、認証はコンテナーの**システム割り当てマネージドID**を選択します。

復元後は用意済みの公開IP（`rehearsalPublicIpId`／`livePublicIpId`）を復元VMのNICへ関連付けます。Bastion接続用のパスワード再設定などは、講師デモ手順書に従ってください。

終了後は[クリーンアップ手順](../01-Azure-Backupによる別VMへの復元.md#7-終了後のクリーンアップ)に従います。Soft deleteなどの保護機能を無効化して削除を回避しないでください。
