# IaaS 05：実フェールオーバーとHTML更新

[前へ](./04-test-failover.md) | [全体・進捗チェック](../../../ハンズオン/01-IaaS-ASRによるDRハンズオン.md) | [次へ](./06-reprotect-to-source.md)

> 現在位置：5 / 8。このページの到達点：元VMを停止し、Region Bで復旧・コミット・HTML更新が完了する。

[前のページ](./04-test-failover.md)のテストを終了してから進みます。以降は通常復旧先VNetのVMを使います。元VM停止・コミットの影響を確認し、組織で必要な承認があれば取得してください。

## Step 7：元VMを停止し、Region Bへ実フェールオーバーする

### 7.1 実フェールオーバーと復旧確認

1. AからBへの複製が正常で、HTML構成後の最新の復旧ポイントがあることを確認します。
2. Portalで**Region Aの専用演習VM**の **停止** を実行し、停止状態になるまで待ちます。操作開始と停止確認の時刻を記録します。元VM・ディスク・グループは削除しません。

   元VMの停止は、障害の模擬と元・復旧先の同時稼働を避けるために行います。Region Aの管理APIまで停止するリージョン障害の完全再現ではありません。

3. コンテナーの **レプリケートされたアイテム** で対象を開き、**フェールオーバー（Failover）** を選択します。今回は **テストフェールオーバー** ではありません。

<p align="center">
  <img src="./files/image-17.png" alt="alt text" width="800">
</p>

4. 複製方向がAからBであることを確認し、**最新（Latest）** を選択します。これはASRへ送信済みのデータを処理して復旧ポイントを生成する方式で、未送信データの損失ゼロを保証するものではありません。
5. **フェールオーバーを開始する前にマシンをシャットダウンする** が表示される場合は選択します。ただし、シャットダウン失敗時も切り替えが続行され得るため、先に行った元VMの停止確認を省略しません。

<p align="center">
  <img src="./files/image-16.png" alt="alt text" width="800">
</p>

6. 実行時刻を記録し、Site Recoveryジョブで成功・失敗とジョブIDを確認します。

<p align="center">
  <img src="./files/image-18.png" alt="alt text" width="800">
</p>


<p align="center">
  <img src="./files/image-19.png" alt="alt text" width="800">
</p>


<p align="center">
  <img src="./files/image-20.png" alt="alt text" width="800">
</p>

7. 作成されたRegion Bの復旧VMが、テスト専用ではなく**通常復旧先VNet**に接続していることを確認します。
8. 復旧VMのNICのプライマリIP構成へ、Region Bの演習専用Standard公開IPv4を関連付けます。元VMのパブリックIPは、別リージョンの復旧VMへ引き継げません。

   > **実運用での接続先の切り替え**：Traffic ManagerによるDNSベースの切り替えや、Azure Front Door、クロスリージョンLoad Balancerを利用すると、利用者がアクセスするURLを変えずに復旧先へ接続を切り替えられます。本演習では、復旧先のパブリックIPを使って手動でアクセスします。

9. 復旧VMの **接続 → Bastion** から、通常復旧先VNetのBastion Developerと`azureuser`・自分で設定した演習専用パスワードで接続します。テストVMのセッションは閉じます。
10. 次のコマンドでApacheの自動起動と、更新前のHTMLの内容を確認します。再インストールやHTML再作成はしません。

```bash
systemctl is-enabled apache2 &&
systemctl is-active apache2 &&
cat /var/www/html/index.html &&
curl --fail --silent --show-error --connect-timeout 5 --max-time 15 http://127.0.0.1/
```

11. 参加者のブラウザーで`http://<Region Bの復旧VMの公開IP>/`を開き、5秒以上の間隔で3回連続して正常表示を確認します。
12. Region Aの元VMは停止したままであることを確認します。元VMを手動で再起動しません。

**確認結果**：Region Bの実際の復旧VMで、元のHTMLマーカーが表示され、Webページを利用できること。本編の入口変更はURLの手動切り替えであり、DNSやFront Doorの切り替えは行いません。

## Step 8：復旧結果をコミットし、Region BでHTMLを更新する

### 8.1 フェールオーバーをコミットする

1. Apache、HTML、利用者経路からの表示、元VMの停止を再確認します。組織で承認が必要な場合は、コミット前に取得します。
2. レプリケートされたアイテムの **コミット（Commit）** を実行します。

<p align="center">
  <img src="./files/image-21.png" alt="alt text" width="800">
</p>

3. コミットジョブの成功と、**Failover committed**に相当する状態を確認します。

<p align="center">
  <img src="./files/image-24.png" alt="alt text" width="800">
</p>


**コミットすると既存の復旧ポイントが削除され、別の復旧ポイントへの変更ができなくなります。** 証拠を保存し、復旧結果を確認してから実行します。コミットは再保護ではなく、この時点では逆方向の複製はまだ開始していません。

### 8.2 復旧先でのアプリの変更

ここでは、フェールオーバ先での運用を想定し、変更を加えます。Region Bの**通常復旧先VM**へBastion Developer経由で演習専用パスワードを使って接続します。

HTML内の`apache-html-ready`を`apache-html-updated-in-region-b`へ置き換えます。

```bash
sudo sed -i 's/apache-html-ready/apache-html-updated-in-region-b/' /var/www/html/index.html
```

エラーがないことを確認してから、更新後の内容を表示します。`apache-html-updated-in-region-b`が含まれていることを確認してください。

```bash
cat /var/www/html/index.html
```

書き込みを反映します。エラーが出た場合は先へ進まず、原因を確認してください。

```bash
sync
```

書き込み完了時刻を表示します。

```bash
printf 'Write completed at UTC: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

1. `Write completed at UTC`と更新後のマーカーをVM外へ記録します。
2. ローカルHTTPとブラウザーで`apache-html-updated-in-region-b`が表示されることを確認します。
3. 以後、フェールバック完了まではHTMLを変更しません。この更新後のマーカーを、戻した先の照合基準にします。

**確認結果**：Bで更新したHTMLが表示され、フェールバックで保持を検証する基準が記録できたこと。`sync`はASRへの送信・複製完了を意味しません。

## このページの完了チェック

- [ ] 元VMを停止して実フェールオーバーし、Bの通常復旧先で元のHTMLマーカーの表示を確認した。
- [ ] 復旧結果を確認・コミットし、Aを停止したままBを稼働先とした。
- [ ] BでHTMLを更新し、表示・更新後のマーカー・時刻をVM外へ記録した。

完了したら[全体ページ](../../../ハンズオン/01-IaaS-ASRによるDRハンズオン.md)の対応するチェックを更新します。

[前へ](./04-test-failover.md) | [全体・進捗チェック](../../../ハンズオン/01-IaaS-ASRによるDRハンズオン.md) | [次へ](./06-reprotect-to-source.md)
