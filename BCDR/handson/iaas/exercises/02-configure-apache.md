# IaaS 02：Apache と HTML の構成

[前へ](./01-verify-deployment.md) | [全体・進捗チェック](../../../ハンズオン/01-IaaS-ASRによるDRハンズオン.md) | [次へ](./03-configure-asr.md)

> 現在位置：2 / 8。このページの到達点：Web ページが表示され、演習用の HTML マーカーを確認できる。

[前のページ](./01-verify-deployment.md)の完了条件を満たしてから進んでください。

## Step 2：Ubuntu へログインし、Apache と HTML を構成する

[00 の Bicep 手順](../preparation/00-create-initial-resources.md) で作成した元 VM へ Bastion Developer で接続します。接続方法は前のページを参照してください。ユーザー名は `azureuser`、パスワードはデプロイ時に設定した演習専用の値です。

> [!IMPORTANT]
> 以降の Bash コマンドは、Bastion で接続した元 VM の Ubuntu ターミナルで実行します。手元の PowerShell や Cloud Shell では実行しません。公開 IP への SSH 接続も行いません。

### 2.1 Apache をインストールし、自動起動を設定する

各コードブロックを実行し、エラーがないことを確認してから次へ進みます。

```bash
sudo apt-get update &&
sudo apt-get install -y apache2 curl
```

```bash
sudo apache2ctl configtest &&
sudo systemctl enable --now apache2 &&
systemctl is-enabled apache2 &&
systemctl is-active apache2
```

```bash
curl --fail --silent --show-error --connect-timeout 5 --max-time 15 -o /dev/null -w 'HTTP %{http_code}\n' http://127.0.0.1/
```

**確認結果**：構文確認が `Syntax OK`、自動起動が `enabled`、稼働状態が `active`、HTTP 応答が `200` となること。ホスト名に関する警告が出た場合も全文を記録し、構文エラーとは区別します。

### 2.2 演習用の index.html を配置する

> [!CAUTION]
> Apache の既定ページを上書きします。専用の演習 VM でのみ実行してください。

#### ① 一時ファイルを vi で開く

Ubuntu のターミナルで、次のコマンドを入力して Enter を押します。

```bash
vi /tmp/index.html
```

ターミナルが vi の編集画面に切り替わります。この時点ではまだ文字を入力せず、次の操作へ進みます。一時ファイルを編集するため、Apache の既定ページはまだ変更されません。

#### ② 文字を入力できるモードに切り替える

vi の画面内をクリックして、キーボードの **`i`** を 1 回押します（Enter は不要です）。これで「挿入モード」になり、文字を入力・貼り付けできるようになります。環境によっては画面下部に `-- INSERT --` と表示されます。

#### ③ HTML を貼り付ける

以下の HTML を **`<!doctype html>` から `</html>` まで全体コピー**し、vi の編集画面に貼り付けます。コードブロックの囲み記号は含めません。

HTML はそのまま使用でき、演習 ID の入力は不要です。

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>ASR Web Recovery Exercise</title>
</head>
<body>
  <h1>ASR Web Recovery Exercise</h1>
  <p>Recovery marker: apache-html-ready</p>
</body>
</html>
```

貼り付けた内容が画面に表示され、先頭が `<!doctype html>`、末尾が `</html>` になっていることを確認します。

#### ④ 保存して vi を終了する

次のキー操作を順に行います。ここでは新しいターミナルコマンドを実行するのではなく、**vi の編集画面で操作**します。

1. **Esc** を押します。挿入モードが終了します。
2. **`:wq`** と入力します。画面下部に `:wq` が表示されます。`w` は保存、`q` は終了です。
3. **Enter** を押します。保存が成功すると vi が閉じ、Ubuntu のコマンドを入力できる画面に戻ります。

保存エラーが表示された場合は、エラーを解決してから次へ進んでください。

#### ⑤ 保存した内容を確認する

Ubuntu のターミナルに戻ったら、次を実行します。

```bash
cat /tmp/index.html
```

**確認結果**：HTML 全体が表示され、タイトル `ASR Web Recovery Exercise` とマーカー `apache-html-ready` が含まれていること。誤りがあれば、もう一度 `vi /tmp/index.html` で開き、修正・保存して再確認します。

#### ⑥ Apache の公開ディレクトリへ配置する

内容に問題がなければ次を実行します。**ここで初めて Apache の既定ページが演習用ページに置き換わります。** 最後に書き込み完了時刻が表示されます。

```bash
sudo install -m 644 /tmp/index.html /var/www/html/index.html
sync
date -u +%Y-%m-%dT%H:%M:%SZ
```

HTML マーカーと表示された UTC 時刻を **VM 外のメモ**に記録します。後で、復旧ポイントの時刻と比較します。

> [!NOTE]
> `sync` は OS 内の書き込みを反映しますが、ASR への送信・複製完了を保証しません。

VM 内のローカル HTTP で、配置した内容が返ることを確認します。

```bash
curl --fail --silent --show-error --connect-timeout 5 --max-time 15 http://127.0.0.1/
```

続いて、参加者 PC のブラウザーで、Bicep デプロイ出力の `sourcePageUrl`（`http://<元VMの公開IP>/`）を開きます。

> [!NOTE]
> `127.0.0.1` は VM 自身を指します。参加者 PC のブラウザーでは `sourcePageUrl` を使います。

**確認結果**：`ASR Web Recovery Exercise` と `apache-html-ready` がローカル HTTP とブラウザーの両方で表示されること。

既定の「Apache2 Ubuntu Default Page」が残っている場合は、配置先とブラウザーキャッシュを確認します。

## このページの完了チェック

- [ ] Apache のインストールと自動起動設定を完了した。
- [ ] HTML の表示を確認し、HTML マーカーと時刻を記録した。

完了したら[全体ページ](../../../ハンズオン/01-IaaS-ASRによるDRハンズオン.md)の対応するチェックを更新します。未完了の場合は進捗メモに停止箇所と理由を残してください。

[前へ](./01-verify-deployment.md) | [全体・進捗チェック](../../../ハンズオン/01-IaaS-ASRによるDRハンズオン.md) | [次へ](./03-configure-asr.md)
