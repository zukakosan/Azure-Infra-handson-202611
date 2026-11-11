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

### 3.1 元VMへ接続する

出力の`sourceVmPortalUrl`から元VMを開き、**接続 → Bastion** でログインします。既定ユーザー名は`azureuser`、パスワードはデプロイ時に入力した値です。

以降の`bash`コマンドは、**Bastionで接続した元Ubuntu VM内**で、ブロックごとに実行します。講師端末のPowerShellや復元VMでは実行しません。エラーが出た場合は原因を解消してから次へ進みます。

### 3.2 Apacheをインストールする

パッケージ一覧を更新し、Apacheと確認用のcurlをインストールします。

```bash
sudo apt-get update &&
sudo apt-get install -y apache2 curl
```

設定を確認し、Apacheの起動と自動起動を有効にします。

```bash
sudo apache2ctl configtest &&
sudo systemctl enable --now apache2 &&
systemctl is-enabled apache2 &&
systemctl is-active apache2
```

`Syntax OK`、`enabled`、`active`が表示されることを確認します。

### 3.3 正常状態のHTMLを配置する

デモ専用の既定ページを、復元確認用の正常なHTMLで上書きします。

```bash
printf '%s\n' '<!doctype html>' '<html lang="en">' \
  '<head><meta charset="utf-8"><title>Azure Backup Demo</title></head>' \
  '<body><h1>Azure Backup Demo</h1>' \
  '<p>Recovery marker: backup-demo-good-v1</p></body></html>' \
  > /tmp/backup-demo-good.html &&
sudo install -m 644 /tmp/backup-demo-good.html /var/www/html/index.html &&
sync &&
sha256sum /var/www/html/index.html &&
date -u +%Y-%m-%dT%H:%M:%SZ
```

HTMLのSHA-256とUTC時刻をVM外に控え、VM内でHTTP応答を確認します。

```bash
curl --fail --silent --show-error --connect-timeout 5 --max-time 15 http://127.0.0.1/
```

講師端末のブラウザーで出力の`sourcePageUrl`を開き、`backup-demo-good-v1`が表示されることを確認します。

### 3.4 正常状態をバックアップする

1. Portalで出力の`vaultName`のRSVを開き、**バックアップ項目 → Azure Virtual Machine → 元VM** を選択します。バックアップ保護とポリシーはBicepで設定済みのため、再登録は不要です。
2. **今すぐバックアップ** を実行し、保持期限はデモ実施日より後に設定します。
3. **バックアップジョブ** で完了を確認し、復旧ポイントの時刻を控えます。**Apache・正常HTMLの構成後に取得したポイントを使います。**
4. [講師デモ手順書のHTML変更](../01-Azure-Backupによる別VMへの復元.md#44-元vmのhtmlを変更し変更後のポイントも取得する)へ進み、変更後のバックアップ取得、事前復元を実施します。

保護設定だけではバックアップ取得完了ではありません。自動実行は日本時間02:00のため、ここでは手動で取得します。

> 旧版の自動インストールで失敗した環境を使う場合：必要なエラーログを記録し、元VMの **拡張機能とアプリケーション** から残っている`setup-backup-demo-web`を削除してから手動構成します。再デプロイだけでは該当拡張機能は削除されません。

## 4. 復元と後片付け

RSVの **バックアップ項目 → Azure Virtual Machine → 元VM → VMの復元** を開き、正常状態の復旧ポイントから **新しい仮想マシンを作成** します。元VMを置き換える方式は選びません。

復元画面では、Bicepのデプロイ実行結果に表示された各項目の`value`を使い、次のように設定します。

| 復元画面の設定項目 | 選択する値 |
|---|---|
| リソースグループ | `restoreResourceGroupName`に表示された名前 |
| 仮想ネットワーク | `restoreVnetId`が示すVNet |
| サブネット | `restoreSubnetId`が示すサブネット |
| ステージング場所（表示された場合） | `stagingStorageAccountName`に表示されたストレージアカウント |
| 復元に使用する認証方式 | **システム割り当てマネージドID** |

`restoreVnetId`と`restoreSubnetId`はリソースIDです。Portalの選択欄にはID全体を貼り付けず、それぞれIDの最後の`/`より後にある名前を選びます。

ここで使うマネージドIDは、**復元先VMではなく、バックアップを保存しているRSV自身のID**です。RSVが復元先へリソースを作成するための権限は、Bicepで設定済みです。詳細な操作は[講師デモ手順書の復元操作](../01-Azure-Backupによる別VMへの復元.md#52-変更前の復旧ポイントから別vmを作成する)を参照してください。

復元後は用意済みの公開IP（`rehearsalPublicIpId`／`livePublicIpId`）を復元VMのNICへ関連付けます。Bastion接続用のパスワード再設定などは、講師デモ手順書に従ってください。

終了後は[クリーンアップ手順](../01-Azure-Backupによる別VMへの復元.md#7-終了後のクリーンアップ)に従います。Soft deleteなどの保護機能を無効化して削除を回避しないでください。
