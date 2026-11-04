# IaaS 02：ApacheとHTMLの構成

[前へ](./01-ネットワークとVMの作成.md) | [全体・進捗チェック](../01-IaaS-ASRによるDRハンズオン.md) | [次へ](./03-ASRの構成と初期複製.md)

> 現在位置：2 / 9。このページの到達点：Webページが表示され、演習IDとメッセージを確認できる。

[前のページ](./01-ネットワークとVMの作成.md)の完了条件を満たしてから進んでください。

時刻・証拠・未取得項目は[観測記録](./09-観測記録と振り返り.md)へ随時記入します。

## このページの手順

### Step 2：Ubuntuへログインし、ApacheとHTMLを構成する

[Step 1](./01-ネットワークとVMの作成.md)で作成した元のVMへ、Portalの **接続 → Bastion** からDeveloper経由でパスワード接続します。ログインしたら、OS情報などの追加確認は行わず、以下のApacheインストールから始めます。

#### 2.1 Apacheをインストールし、自動起動を設定する

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

#### 2.2 演習用のindex.htmlを配置する

既存のApache既定ページを上書きします。専用の演習VM以外では実行しません。

1. `vi /tmp/index.html` を実行します。一時ファイルを使うため、編集中に既定ページを壊しません。
2. `i` キーで挿入モードにし、以下のHTML全体を貼り付けます。
3. `YOUR_EXERCISE_ID`を自分の演習IDに置き換えます。今回の環境では演習IDは`a7k3p9`です。
4. `Esc` キーを押し、`:wq` と入力してEnterを押し、保存して終了します。

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
  <p>Exercise ID: YOUR_EXERCISE_ID</p>
  <p>Recovery marker: apache-html-ready</p>
</body>
</html>
```

一時ファイルの内容を確認してからApacheの公開ディレクトリへ配置します。

```bash
cat /tmp/index.html
```

内容に問題がなければ配置し、書き込み完了時刻を確認します。

```bash
sudo install -m 644 /tmp/index.html /var/www/html/index.html
sync
date -u +%Y-%m-%dT%H:%M:%SZ
```

演習ID、メッセージ、表示されたUTC時刻を**VM外の観測シート**に記録します。UTC時刻はASRの復旧ポイントがHTML更新を含むか確認するために使います。`sync`はOS内の書き込みを反映させる操作であり、ASRの複製完了を保証するものではありません。`vi`の保存に失敗した場合は、成功扱いにせずエラーを確認します。内容に誤りがあれば、一時ファイルを修正してから配置します。

ローカルHTTPで配置した内容が返ることを確認します。

```bash
curl --fail --silent --show-error --connect-timeout 5 --max-time 15 http://127.0.0.1/
```

続いて、配布された接続経路の端末・ブラウザーで`http://<元のVMへ到達できるIPまたはホスト名>/`を開きます。`127.0.0.1`は実行している端末自身を指すため、参加者のPCで元VMのアドレスとして使いません。

**確認結果**：演習IDと`apache-html-ready`がローカルHTTPとブラウザーの両方で表示されること。既定の「Apache2 Ubuntu Default Page」が残っている場合は、配置先とキャッシュを確認します。

## このページの完了チェック

- [ ] Apacheのインストールと自動起動設定を完了した。
- [ ] HTMLの表示を確認し、演習IDとメッセージを記録した。

完了したら[全体ページ](../01-IaaS-ASRによるDRハンズオン.md)の対応するチェックを更新します。未完了の場合は進捗メモに停止箇所と理由を残してください。

[前へ](./01-ネットワークとVMの作成.md) | [全体・進捗チェック](../01-IaaS-ASRによるDRハンズオン.md) | [次へ](./03-ASRの構成と初期複製.md)
