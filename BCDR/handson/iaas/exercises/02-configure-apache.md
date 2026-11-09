# IaaS 02：ApacheとHTMLの構成

[前へ](./01-verify-deployment.md) | [全体・進捗チェック](../../../ハンズオン/01-IaaS-ASRによるDRハンズオン.md) | [次へ](./03-configure-asr.md)

> 現在位置：2 / 8。このページの到達点：Webページが表示され、演習用のHTMLマーカーを確認できる。

[前のページ](./01-verify-deployment.md)の完了条件を満たしてから進んでください。

## Step 2：Ubuntuへログインし、ApacheとHTMLを構成する

[00のBicep手順](../preparation/00-create-initial-resources.md)で作成した元VMへ、Portalの **接続 → Bastion** からDeveloper経由で接続します。ユーザー名は`azureuser`、パスワードはデプロイ時に設定した演習専用の値です。公開IPへSSH接続しません。

### 2.1 Apacheをインストールし、自動起動を設定する

各コードブロックの成功を確認してから次へ進みます。

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

**確認結果**：構文確認が`Syntax OK`、自動起動が`enabled`、稼働状態が`active`、HTTP応答が`200`となること。ホスト名に関する警告が出た場合も全文を記録し、構文エラーとは区別します。

### 2.2 演習用のindex.htmlを配置する

既存のApache既定ページを上書きします。専用の演習VM以外では実行しません。

#### ① 一時ファイルをviで開く

**Bastionで接続したUbuntuのターミナル**で、次のコマンドを入力してEnterを押します。手元のPowerShellでは実行しません。

```bash
vi /tmp/index.html
```

ターミナルがviの編集画面に切り替わります。この時点ではまだ文字を入力せず、次の操作へ進みます。一時ファイルを編集するため、Apacheの既定ページはまだ変更されません。

#### ② 文字を入力できるモードに切り替える

viの画面内をクリックして、キーボードの **`i`** を1回押します（Enterは不要です）。これで「挿入モード」になり、文字を入力・貼り付けできるようになります。環境によっては画面下部に`-- INSERT --`と表示されます。

#### ③ HTMLを貼り付ける

以下のHTMLを **`<!doctype html>`から`</html>`まで全体コピー**し、viの編集画面に貼り付けます。コードブロックの囲み記号は含めません。

HTMLはそのまま使用でき、演習IDの入力は不要です。

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

貼り付けた内容が画面に表示され、先頭が`<!doctype html>`、末尾が`</html>`になっていることを確認します。

#### ④ 保存してviを終了する

次のキー操作を順に行います。ここでは新しいターミナルコマンドを実行するのではなく、**viの編集画面で操作**します。

1. **Esc**を押します。挿入モードが終了します。
2. **`:wq`**と入力します。画面下部に`:wq`が表示されます。`w`は保存、`q`は終了です。
3. **Enter**を押します。保存が成功するとviが閉じ、Ubuntuのコマンドを入力できる画面に戻ります。

エラーが表示されてviが閉じない場合は、保存できていません。エラー内容を確認し、解決するまで次へ進まないでください。

#### ⑤ 保存した内容を確認する

Ubuntuのターミナルに戻ったら、次を実行します。

```bash
cat /tmp/index.html
```

**確認結果：** HTML全体が表示され、タイトル`ASR Web Recovery Exercise`とマーカー`apache-html-ready`が含まれていること。誤りがあれば、もう一度`vi /tmp/index.html`で開き、修正・保存して再確認します。

#### ⑥ Apacheの公開ディレクトリへ配置する

内容に問題がなければ次を実行します。**ここで初めてApacheの既定ページが演習用ページに置き換わります。** 最後に書き込み完了時刻が表示されます。

```bash
sudo install -m 644 /tmp/index.html /var/www/html/index.html
sync
date -u +%Y-%m-%dT%H:%M:%SZ
```

HTMLマーカーと表示されたUTC時刻を**VM外の任意のメモ**に控えます。UTC時刻はASRの復旧ポイントがHTML更新を含むか確認するために使います。`sync`はOS内の書き込みを反映させる操作であり、ASRの複製完了を保証するものではありません。`vi`の保存に失敗した場合は、成功扱いにせずエラーを確認します。内容に誤りがあれば、一時ファイルを修正してから配置します。

ローカルHTTPで配置した内容が返ることを確認します。

```bash
curl --fail --silent --show-error --connect-timeout 5 --max-time 15 http://127.0.0.1/
```

続いて、Bicepデプロイ出力の`sourcePageUrl`（`http://<元VMの公開IP>/`）をブラウザーで開きます。`127.0.0.1`はVM自身を指すため、参加者PCでは使いません。

**確認結果**：`ASR Web Recovery Exercise`と`apache-html-ready`がローカルHTTPとブラウザーの両方で表示されること。既定の「Apache2 Ubuntu Default Page」が残っている場合は、配置先とキャッシュを確認します。

## このページの完了チェック

- [ ] Apacheのインストールと自動起動設定を完了した。
- [ ] HTMLの表示を確認し、HTMLマーカーと時刻を記録した。

完了したら[全体ページ](../../../ハンズオン/01-IaaS-ASRによるDRハンズオン.md)の対応するチェックを更新します。未完了の場合は進捗メモに停止箇所と理由を残してください。

[前へ](./01-verify-deployment.md) | [全体・進捗チェック](../../../ハンズオン/01-IaaS-ASRによるDRハンズオン.md) | [次へ](./03-configure-asr.md)
