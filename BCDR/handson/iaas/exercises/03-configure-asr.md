# IaaS 03：ASR の構成と初期複製

[前へ](./02-configure-apache.md) | [ハンズオンの進め方](../README.md) | [次へ](./04-test-failover.md)

> 現在位置：3 / 8。このページの到達点：初期複製が完了し、HTML 構成後の復旧ポイントを確認できる。

[前のページ](./02-configure-apache.md)の完了条件を満たしてから進んでください。

## Step 3：Portal で ASR を有効化し、初期複製を待つ

### 3.1 作成済みの Recovery Services コンテナーを確認する

[事前準備](../preparation/00-create-initial-resources.md)でコンテナーと両リージョンのキャッシュストレージは作成済みです。ここでは、マネージド ID の確認とアクセス権の付与を行います。ASR の複製は 3.2 で有効にします。

1. Portal で、Bicep 出力 `recoveryVaultId` に対応する Recovery Services コンテナーを開きます。
2. 名前が `rsv-bcdr-<演習ID>`、所属グループが `rg-bcdr-dr-<演習ID>`、リージョンが Region B であることを確認します。
3. コンテナーの **ID（Identity）→ システム割り当て** を開き、**状態：オン** を確認します。**オフの場合はオンに変更し、保存を押して、確認画面が表示された場合は承認します。**
4. 保存が完了し、状態が **オン**、**オブジェクト（プリンシパル）ID** が表示されていることを確認します。このマネージド ID を、次のストレージへの権限付与先にします。

<p align="center">
  <img src="files/image-40.png" alt="alt text" width="800">
</p>


#### 3.1.1 キャッシュストレージとアクセス権限を準備する

キャッシュストレージは、複製元 VM と同じリージョンに必要です。通常の A→B 用を Region A に、再保護の B→A 用を Region B に用意します。

ストレージ名は自分の Bicep 出力で確認します。`<演習ID>` は自分の演習 ID に置き換えてください。

> [!IMPORTANT]
> レプリケーションを有効にする前に、両方のストレージへの権限付与を完了してください。付与先は、ユーザーや Automation アカウントではなく、コンテナーのマネージド ID です。

| 用途 | ストレージアカウント | リソースグループ | リージョン |
|---|---|---|---|
| A→B の複製用 | Bicep 出力 `sourceCacheStorageAccountName` | `rg-bcdr-src-<演習ID>` | Region A |
| B→A の再保護用 | Bicep 出力 `recoveryCacheStorageAccountName` | `rg-bcdr-dr-<演習ID>` | Region B |

1. Bicep 出力 `sourceCacheStorageAccountName`（Region A の元のリソースグループ）と `recoveryCacheStorageAccountName`（Region B の DR 用リソースグループ）のストレージを確認します。Bicep で **Standard・LRS・StorageV2**、HTTPS のみ・最小 TLS 1.2、匿名 Blob アクセス・共有キーアクセス無効として作成済みです。
2. 各ストレージアカウントの **アクセス制御（IAM）→ 追加 → ロールの割り当ての追加** から、以下の 2 つのロールを 3.1 で確認したコンテナーのマネージド ID へ割り当てます。

   - **ロール** タブで下表のロールを 1 つ選び、**次へ** を押します。
   - **メンバー** タブで **アクセスの割り当て先：マネージド ID → メンバーを選択する** を開きます。
   - 演習用サブスクリプションと、Recovery Services コンテナーに対応するマネージド ID の種類を選び、自分の演習 ID に対応する `rsv-bcdr-<演習ID>` を選択します。
   - **選択 → レビューと割り当て** で確定します。もう 1 つのロールについても同じ操作を行い、もう一方のストレージでも繰り返します。

   | ロール | スコープ |
   |---|---|
   | **共同作成者（Contributor）** | 対象のストレージアカウントのみ |
   | **ストレージ BLOB データ共同作成者（Storage Blob Data Contributor）** | 対象のストレージアカウントのみ |

<p align="center">
  <img src="files/image-41.png" alt="alt text" width="800">
</p>


<p align="center">
  <img src="files/image-42.png" alt="alt text" width="800">
</p>


> 参考：[ASR で使用するストレージへのアクセス権限（Microsoft Learn）](https://learn.microsoft.com/azure/site-recovery/site-recovery-faq#security)

3. **ロールの割り当て**で、2 アカウントそれぞれに 2 ロール、合計 4 件の割り当てと付与先を確認し、反映を待ちます。ストレージ名・リージョン・ID を記録します。権限がない場合はサブスクリプション管理者へ割り当てを依頼します。

### 3.2 Azure VM のレプリケーションを有効にする

> [!IMPORTANT]
> Trusted Launch の Linux VM は、VM 作成画面ではなく、以下のコンテナーからの手順で複製を有効にします。Ubuntu 22.04 と実際のカーネルが[サポート対象](https://learn.microsoft.com/ja-jp/azure/site-recovery/concepts-trusted-vm)であることを確認してください。

1. コンテナーの **Site Recovery** を開き、**Azure 仮想マシン → レプリケーションを有効にする（Enable replication）** を選択します。

> [!NOTE]
> ASR は Secure Boot・vTPM 設定を保持しますが、ブート整合性監視の状態は複製しません。

<p align="center">
  <img src="./files/image.png" alt="alt text" width="800">
</p>


<p align="center">
  <img src="./files/image-1.png" alt="alt text" width="800">
</p>


2. **ソース** で Region A、演習用サブスクリプション、元のリソースグループを選択します。ゾーン間 DR ではなくリージョン間 DR を選択します。

<p align="center">
  <img src="./files/image-3.png" alt="alt text" width="800">
</p>


3. **仮想マシン** で自分の元 VM だけを選択します。

<p align="center">
  <img src="./files/image-4.png" alt="alt text" width="800">
</p>


4. **レプリケーション設定** で、以下の各パートを順に設定します。自動提案された値をそのまま使わず、自分の演習環境に合わせてください。

#### 場所およびリソースグループ

画面上部の **場所およびリソースグループ** で、復旧先を指定します。

| 項目 | 設定・確認 |
|---|---|
| ターゲットの場所 | Region B |
| ターゲットサブスクリプション | 演習用サブスクリプション |
| ターゲットリソースグループ | 作成済みの `rg-bcdr-dr-<演習ID>` |

#### ネットワーク

続いて **ネットワーク** で、Region B の DR 用グループにある作成済み VNet を選択します。自動作成候補や元用（`src`）・テスト用（`test`）VNet は選びません。

| 項目 | 設定・確認 |
|---|---|
| フェールオーバー仮想ネットワーク | `vnet-bcdr-dr-<演習ID>` |
| フェールオーバーサブネット | `subnet-web` |

<p align="center">
  <img src="./files/image-5.png" alt="alt text" width="800">
</p>

テスト用 VNet はここでは選択せず、テストフェールオーバー時に指定します。
#### ストレージ

**ストレージ構成の表示／編集** を開きます。

<p align="center">
  <img src="./files/image-8.png" alt="alt text" width="800">
</p>

開いた設定画面で、複製対象ディスクとキャッシュストレージを設定します。

> [!IMPORTANT]
> キャッシュストレージは、3.1.1 で権限付与した Region A の既存ストレージを選択します。自動作成候補は使用しません。

| 項目 | 設定・確認 |
|---|---|
| レプリケーション用にディスクを含める | はい |
| キャッシュストレージ | Bicep 出力 `sourceCacheStorageAccountName` と同じ名前。所属グループは `rg-bcdr-src-<演習ID>`、リージョンは Region A |
| VM のチャーン（データ変更率） | 通常の変更率（Normal Churn／ノーマル チャーン） |

<p align="center">
  <img src="./files/image-9.png" alt="alt text" width="800">
</p>

設定を確認して変更を保存し、レプリケーション設定画面へ戻ります。Region B のキャッシュストレージは、後の逆方向の再保護用で、ここでは指定しません。

5. **管理** で次の設定を行います。
   - 複製ポリシーを確認します。本演習は単一 VM のため、複数 VM の整合性用グループは新規構成しません。
   - **拡張機能の設定 → 設定の更新** で **ASR に管理を許可します** を選択します。
   - **Automation アカウント** の新規作成候補を確認して **作成** を押し、作成されたアカウントの名前とリソースグループを記録します。

   > [!NOTE]
   > この設定は、VM 内の Mobility サービス（複製エージェント）の更新を自動化します。OS や Apache の更新設定ではありません。

<p align="center">
  <img src="./files/image-6.png" alt="alt text" width="800">
</p>


6. **確認** 画面で、ターゲットが Region B の `rg-bcdr-dr-<演習ID>`・`vnet-bcdr-dr-<演習ID>`・`subnet-web` であることと、キャッシュストレージが Bicep 出力 `sourceCacheStorageAccountName` と一致していることを確認してから、**レプリケーションを有効にする** を実行します。
7. コンテナーの **Site Recovery ジョブ** で有効化処理を、**レプリケートされたアイテム** で初期複製の進行状況を確認します。

<p align="center">
  <img src="./files/image-7.png" alt="alt text" width="800">
</p>


**確認結果**：自分の VM がレプリケートされたアイテムに登録され、指定した Region B への初期複製が開始すること。Mobility サービスなど必要な構成は ASR の有効化処理で導入されます。

#### 3.2.1 初期複製中にネットワークマッピングを確認する

1. Recovery Services コンテナーの **Site Recovery インフラストラクチャ → Azure 仮想マシン → ネットワーク マッピング** を開き、Region A の元 VNet から Region B の復旧先 VNet へのマッピングを確認します。手順 3.2 で復旧先ネットワークを選んだとき、対応するマッピングが自動作成されている場合があります。
2. 反対方向（Region B から Region A）のマッピングも確認します。再保護・フェールバック時に逆方向のネットワーク選択の既定値として使われます。


<p align="center">
  <img src="./files/image-37.png" alt="ネットワークマッピングの例" width="800">
</p>


ネットワークマッピングは、元 VNet と復旧先 VNet の対応関係です。実際の復旧 VM の接続先は、レプリケートされたアイテムの **ネットワーク** 設定でも確認します。

> [!IMPORTANT]
> 通常の復旧では Region B の復旧先 VNet を使います。テストフェールオーバーでは、競合を避けるためテスト専用 VNet を別途指定します。マッピングがあっても、テスト用 VNet に自動で切り替わるわけではありません。

<details>
<summary>補足（任意）：ネットワークマッピングの仕組み</summary>

マッピングは、VNet そのものを複製したり、VNet 間の接続（ピアリング、VPN、ルート、DNS、NSG）を作成したりする機能ではありません。

サブネットは名前が一致すれば復旧先でも同名のものが選ばれ、なければ復旧先 VNet の先頭のサブネットが既定で選ばれます。マッピングの変更は既存 VM のネットワーク設定を変更せず、新しく複製を有効にする VM の既定値に影響します。

参考：[Azure Site Recovery のネットワーク マッピングと IP アドレス設定](https://learn.microsoft.com/azure/site-recovery/azure-to-azure-network-mapping)

</details>

#### 3.2.2 初期複製中に複製ポリシーを確認する

初期複製の完了を待つ間に、対象 VM に割り当てたポリシーを確認します。

> [!IMPORTANT]
> この節では設定値を変更しません。複製ポリシーの変更は、そのポリシーを使っている既存の複製にも適用されます。

1. Recovery Services コンテナーの **Site Recovery インフラストラクチャ → レプリケーション ポリシー** を開き、対象 VM に割り当てられたポリシーを選択します。
2. 次の項目を画面で確認します。

   | 項目 | 確認する内容 |
   |---|---|
   | 復旧ポイントの保持期間 | どれだけ過去まで復旧ポイントを保持するかを決めます。Azure VM 間の新規ポリシーは通常 24 時間（1 日）です。これは複製の間隔ではありません。 |
   | アプリ整合性スナップショットの頻度 | `0` 時間なら無効です。`0` 以外なら指定間隔でアプリ整合性の復旧ポイントを作成します。アプリがメモリ上のデータや処理中のトランザクションをディスクへ反映できるよう調整します。 |
   | クラッシュ整合性の復旧ポイント | 既定で 5 分ごとに作成され、この間隔は変更できません。アプリ整合性が無効でも作成されます。 |

<details>
<summary>補足（任意）：復旧ポイントの考え方</summary>

**クラッシュ整合性とアプリ整合性**

- **クラッシュ整合性**は、スナップショット時点でディスクに書き込まれていたデータを記録します。メモリ上のデータや処理中のトランザクションは含まれず、VM の電源が突然切れたときに近い状態です。OS や、再起動後に自力で回復できる多くのアプリではこれで十分な場合があります。
- **アプリ整合性**は、スナップショット前にアプリのデータをディスクへ反映し、処理中のトランザクションなどを考慮した状態を作ります。データベースなど、クラッシュ後の回復に任せるだけでは不十分なワークロードで使います。取得時にはアプリの処理や VM 性能への影響があり、アプリ側の対応状況も確認が必要です。

アプリ整合性でも、論理的な正しさや外部システムとの整合性は保証せず、バックアップの代わりにもなりません。本演習の Apache と静的 HTML は、ディスクへの書き込みが完了していればクラッシュ整合性で復旧できる想定です。

**複製と保持期間**

ASR によって、VM のディスク書き込みは継続的に複製元リージョンのキャッシュストレージへ転送され、処理後に復旧先へ送られます。複製先のデータから復旧ポイントが作られ、保持期間に従って古いポイントが整理されます。

保持期間が 24 時間、アプリ整合性の頻度が 1 時間の例では、クラッシュ整合性ポイントは直近 2 時間分が 5 分間隔で残り、それより古い時間帯ではおおむね 1 時間ごとのポイントに間引かれます。**「5 分」は作成間隔、「保持期間」は復旧ポイントを遡れる範囲です。** 1 時間後にすべて削除されるわけではありません。

実際のポリシー値や選択可能な復旧ポイントは環境・状態により異なります。ポリシー画面の値と、保護対象 VM の **テストフェールオーバー** 画面に表示される復旧ポイントを照合してください。

> 参考：[Azure Site Recovery の Azure-to-Azure レプリケーション ポリシー](https://learn.microsoft.com/azure/site-recovery/azure-to-azure-architecture#replication-policy)、[復旧ポイントに関する FAQ](https://learn.microsoft.com/azure/site-recovery/azure-to-azure-troubleshoot-errors#replication-policy)

</details>

> [!IMPORTANT]
> **ここから初期複製の完了待ちです。** ASR 有効化後に、初回の同期が完了するのを待つ必要があります。
>
> 待ち時間は、座学・質疑応答・休憩に充ててください。再開後は、**初期複製の完了と復旧ポイントを確認してから**先へ進みます。

### 3.3 初期複製完了後の確認

#### 3.3.1 初期複製完了と構成後の復旧ポイントを確認する

> [!IMPORTANT]
> テストフェールオーバーの設定画面は、復旧ポイントの確認だけに使います。ここでは実行せず、確認後に閉じてください。テストの実行は次のページで行います。

1. Portal で **Recovery Services コンテナー → 保護されたアイテム → レプリケートされたアイテム → 対象 VM** を開き、次を確認します。
   - **概要** で、初期複製の完了、レプリケーションの正常性、最新の復旧ポイントの時刻を確認します。
   - 選択可能な復旧ポイントは **テストフェールオーバー** の設定画面で確認します。
   - 実行せずに設定画面を閉じます。

<p align="center">
  <img src="./files/image-10.png" alt="alt text" width="800">
</p>

2. 最新の復旧ポイントが、HTML 更新後に記録した UTC 時刻より後であることを確認します。更新内容の保持は、次のテストフェールオーバーで HTML マーカーを照合して確認します。

<p align="center">
  <img src="./files/image-11.png" alt="alt text" width="800">
</p>

3. 任意：対象 VM の RPO（復旧ポイントの遅れ）、エージェントの状態、関連ジョブを確認します。設定変更やフェールオーバーは実行しません。

**確認結果**：初期複製が完了し、Apache と HTML を構成した後の復旧ポイントを選択できること。

HTML の復旧は[次のテストフェールオーバー](./04-test-failover.md)で確認します。

> [!IMPORTANT]
> 待機上限を超えたら作業を停止して原因を調べます。復旧先で Apache や HTML を作り直して成功扱いにしないでください。

<details>
<summary>補足（任意）：Azure CLI で初期複製の進捗を確認する</summary>

参加者 PC の PowerShell で実行します（Ubuntu VM 内ではありません）。Azure CLI で演習用サブスクリプションへログインし、`<演習ID>` を自分の Bicep パラメータに合わせて置き換えてください。以下は状態を読み取るだけで、構成を変更しません。

```powershell
$exerciseId = '<演習ID>'
$subscriptionId = az account show --query id -o tsv
$vaultId = "/subscriptions/$subscriptionId/resourceGroups/rg-bcdr-dr-$exerciseId/providers/Microsoft.RecoveryServices/vaults/rsv-bcdr-$exerciseId"
az rest --method get --url "https://management.azure.com$vaultId/replicationProtectedItems?api-version=2024-04-01" --query 'value[].{VM:properties.friendlyName,State:properties.protectionState,Health:properties.replicationHealth,ProgressPercent:properties.providerSpecificDetails.monitoringPercentageCompletion}' -o table
```

- `State`：`InitialReplicationInProgress` は初期複製中です。
- `ProgressPercent`：初期複製の進捗率です。**復旧ポイント生成そのものの進捗率ではありません。** 表示の更新に間隔があるため、しばらく同じ値になる場合があります。
- `Health`：`Normal` は正常性の表示であり、初期複製完了を意味しません。

進捗を再確認するときは、最後の `az rest` コマンドを再実行します。初期複製完了後は、この節の Portal 手順で最新の復旧ポイントの時刻を確認してください。一覧が空の場合は、まだ保護対象 VM が登録されていない可能性があるため、Site Recovery ジョブの状態を確認します。

</details>

#### 3.3.2 ターゲット VM サイズを確認する

ASR は通常、元 VM と同じサイズ、または近いサイズを復旧先に自動選択します。**ターゲット VM サイズは、レプリケーション後の対象アイテムで確認します。**

1. Recovery Services コンテナーの **レプリケートされたアイテム** から、自分の元 VM に対応するアイテムを開きます。
2. **コンピューティングとネットワーク（Compute and Network）** を開き、ターゲット VM サイズを確認します。

   | 項目 | 確認する内容 |
   |---|---|
   | ターゲット VM サイズ | 演習で使用するサイズ（既定は `Standard_D2s_v5`）になっており、Region B でサービス対応・クォータ・容量を確認していること |

<p align="center">
  <img src="files/image-43.png" alt="alt text" width="800">
</p>

3. ネットワークとディスクの設定も確認します。

> [!NOTE]
> ターゲット VM サイズが演習で使用するサイズと異なる場合は、**編集** から確認済みのサイズへ変更します。


## 次へ進む前の確認

- Bicep で作成済みのコンテナーを確認し、対象 VM のリージョン間複製を有効化した。
- 両リージョンのキャッシュストレージをスコープとして、コンテナーのマネージド ID に必要な 2 つのロールを割り当てた。
- 複製元と同じリージョンのキャッシュストレージを選択した。
- 双方向のネットワークマッピングと役割を確認した。
- 割り当てられた複製ポリシーの設定値を確認した（設定値は変更していない）。
- 初期複製が完了し、構成後の復旧ポイントと複製正常性を確認した。
- ターゲット VM サイズが演習で使用するサイズになっていることを確認した。

[前へ](./02-configure-apache.md) | [ハンズオンの進め方](../README.md) | [次へ](./04-test-failover.md)
