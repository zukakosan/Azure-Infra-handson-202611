# IaaS 補足：トラブルシューティング

[ハンズオンの進め方](../README.md) | [クリーンアップ](./08-cleanup.md)

演習中に困ったときに参照してください。

## 1. まず確認すること

- **操作対象**：元 VM、テスト用 VM、現在稼働中の復旧 VM を取り違えていないか。VM 名・リージョン・VNet を確認します。
- **現在の工程**：テストフェールオーバー、実フェールオーバー、再保護のどの操作か。現在の稼働先と複製方向を確認します。
- **ジョブの状態**：Recovery Services コンテナーの **Site Recovery ジョブ** で、対象ジョブの状態とエラー詳細を確認します。ジョブ成功と Web 表示成功は別に確認します。

管理者へ確認するときは、ページ・Step、対象 VM・リージョン、ジョブ ID・エラー、最後に成功した確認を伝えます。

> [!CAUTION]
> パスワードなどの秘密情報は共有しないでください。

## 2. よくある問題と対処

### コマンド実行

| 状況 | 確認・対応 |
|---|---|
| Bash コマンドを手元で実行してエラーになる | 各ページの `bash` コードは、Bastion で対象の Ubuntu VM へログインした後に実行します。手元の PowerShell や Cloud Shell では実行しません |
| パッケージの更新・インストールに失敗 | VM の送信通信、名前解決、配布先、パッケージ管理のエラーを確認します。成功を確認してから次へ進みます |

### 接続と HTML

| 状況 | 確認・対応 |
|---|---|
| 元の公開 IP で復旧先へアクセスできない | 元 VM の公開 IP は復旧先へ引き継がれません。復旧先 NIC に関連付けた公開 IP と、ブラウザーで開いた URL を確認します |
| VM は起動したが Bastion で接続できない | 対象 VM の VNet・プライベート IP、Bastion、NSG、ルートを確認します。公開 IP は HTTP 確認用で、SSH の接続先にはしません |
| Apache が起動しない | 下の診断コマンドで設定・サービス状態・ログを確認します。復旧先で再インストールして成功扱いにしません |
| VM 内の curl は成功、ブラウザーは失敗 | 対象の公開 IP、TCP 80 の NSG・OS Firewall、ルート、参加者の HTTP 接続経路を確認します。Bastion ログイン成功と HTTP 到達は別です |
| HTML が既定ページ／内容不一致 | 更新後の復旧ポイント、保存先ディスク、対象 VM、ブラウザーキャッシュを確認します。復旧先で HTML を上書きして成功扱いにしません |

### 複製と切り替え

| 状況 | 確認・対応 |
|---|---|
| 復旧ポイントがない／複製異常 | 初期複製、エージェント、送信通信、キャッシュストレージを確認します |
| フェールオーバーで VM 作成に失敗 | ジョブの詳細、権限、復旧先のクォータ、VM サイズの容量、ネットワーク設定を確認します |
| テスト用 VM を削除したのに元のリージョンへ戻っていない | テストのクリーンアップはフェールバックではありません。実切り替え後に戻す手順は [07：フェールバックと再保護](./07-failback-and-reprotect.md)です |
| 再保護が選択できない | フェールオーバーのコミット状態、戻す先のリージョン・権限・リソース、ジョブの状態を確認します |
| 再保護が完了しない／更新後の復旧ポイントがない | ジョブ詳細、キャッシュストレージ、送信通信、容量を確認します。解消するまでフェールバックへ進みません |
| VM 操作が Read-only ロックで拒否される | ASR の保護状態を確認し、ロックを手動解除して回避しません。フェールバック前の B の停止が拒否された場合は [07 の 10.1](./07-failback-and-reprotect.md#101-戻す準備を確認しportal-から-region-b-の-vm-を停止する) の代替手順に従い、停止完了も確認します |
| フェールバック後のマーカー不一致 | B で控えたマーカー、更新後の復旧ポイント、戻した VM を確認します。A で同じ HTML を作り直して成功扱いにしません |

### 削除と課金

| 状況 | 確認・対応 |
|---|---|
| クリーンアップ後もリソースや課金が残る | テスト用 VM の削除だけでは演習環境全体は削除されません。[08：クリーンアップ](./08-cleanup.md)で複製無効化、専用リソースの削除、残存リソースを確認します |

### Apache の診断コマンド

対象の Ubuntu VM へ Bastion でログインして実行します。エラーが出ても後続の診断を確認できるよう、1 行ずつ実行してください。

```bash
sudo apache2ctl configtest
sudo systemctl status apache2 --no-pager
sudo journalctl -u apache2 --no-pager -n 50
```

## 3. 作業を停止する条件

- **停止条件**：ジョブ失敗、または設定した待機上限の超過。**対応**：原因を調べます。原因を確認せず再試行したり、通常のフェールオーバーでテストを代替したりしません。
- **停止条件**：テスト用 VM から本番へ通信できた。**対応**：VM を停止・隔離して影響を確認します。
- **停止条件**：実フェールオーバー／フェールバック中に両リージョンの Web が稼働している（隔離したテスト用 VM との同時稼働は除く）。**対応**：稼働先とデータを確認し、元 VM を無条件に起動しません。
- **停止条件**：切り替え前の復旧ポイント・停止状態を確認できない、または切り替え後の Web 表示・HTML マーカーが一致しない。**対応**：コミットせず、対象・ジョブ結果・表示内容を確認します。
- **停止条件**：削除対象に共有リソースや他の保護対象が含まれている。**対応**：削除やロックの強制解除は行いません。

権限・ポリシー・クォータなど参加者が変更できない問題はサブスクリプション管理者へ確認します。

## 4. 結果を解釈するときの注意

- **ジョブ成功 ≠ 業務復旧**：ジョブの成功だけでは、利用者がサービスを使えるとは限りません。VM 内の HTTP 応答、利用者経路からの表示、HTML マーカーをそれぞれ確認します。
- **今回の所要時間 ≠ 業務全体の RTO**：実障害の検知・承認、本番 DNS、認証、DB、外部依存、全利用者の復旧は検証していません。時間を記録する場合は、起点・終点とタイムゾーンをそろえます。
- **マーカー一致 ≠ RPO ゼロの保証**：マーカー一致で確認できるのは表示内容の保持であり、実障害時のデータ損失ゼロやファイル全体の完全一致ではありません。復旧ポイントとの時刻比較に使うため、マーカーと HTML 更新後の UTC 時刻（`Write completed at UTC`）は VM 外のメモに記録します。

## 5. 参考資料

- [Microsoft Learn：Linux VM で Web サーバーを構成する](https://learn.microsoft.com/ja-jp/azure/virtual-machines/linux/tutorial-lamp-stack)
- [Microsoft Learn：Portal で Linux VM を作成する](https://learn.microsoft.com/ja-jp/azure/virtual-machines/linux/quick-create-portal)
- [Microsoft Learn：Azure VM の DR を設定する](https://learn.microsoft.com/ja-jp/azure/site-recovery/azure-to-azure-tutorial-enable-replication)
- [Microsoft Learn：Trusted Launch VM での ASR 対応条件](https://learn.microsoft.com/ja-jp/azure/site-recovery/concepts-trusted-vm)
- [Microsoft Learn：Azure VM の DR 訓練を実行する](https://learn.microsoft.com/ja-jp/azure/site-recovery/azure-to-azure-tutorial-dr-drill)
- [Microsoft Learn：Azure VM のフェールオーバーとフェールバック](https://learn.microsoft.com/ja-jp/azure/site-recovery/azure-to-azure-tutorial-failover-failback)
- [Microsoft Learn：フェールオーバー後の Azure VM を再保護する](https://learn.microsoft.com/ja-jp/azure/site-recovery/azure-to-azure-how-to-reprotect)
- [Microsoft Learn：Recovery Services コンテナーを削除する](https://learn.microsoft.com/ja-jp/azure/backup/backup-azure-delete-vault)

[ハンズオンの進め方へ](../README.md)
