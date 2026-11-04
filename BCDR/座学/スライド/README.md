# BCDR座学スライド

[BCDRアジェンダ](../../azure-dr-workshop-agenda.md)と[座学のゴール](../00-BCDR座学のゴール.md)に対応する、導入と第1～7章の投影資料です。

## 成果物

- [統合PowerPoint](./v1/v1-Azure-BCDR-座学.pptx)
- [確認用PDF](./v1/v1-Azure-BCDR-座学.pdf)
- 統合版は44枚です。各章フォルダの `v1` に、その章だけのPowerPointとPDFを保存します。

| 章 | 枚数 | PowerPoint |
|---|---:|---|
| 導入：座学のゴール | 3 | [第0章](./00-BCDR座学のゴール/v1/v1-00-BCDR座学のゴール.pptx) |
| DRの目的と基本概念 | 5 | [第1章](./01-DRの目的と基本概念/v1/v1-01-DRの目的と基本概念.pptx) |
| RTO／RPOとDRパターン | 7 | [第2章](./02-RTO-RPOとDRパターン/v1/v1-02-RTO-RPOとDRパターン.pptx) |
| Azureサービス別のDR設計 | 10 | [第3章](./03-Azureサービス別のDR設計/v1/v1-03-Azureサービス別のDR設計.pptx) |
| マルチリージョン構成と切り替え | 3 | [第4章](./04-マルチリージョン構成と切り替え/v1/v1-04-マルチリージョン構成と切り替え.pptx) |
| Front Doorフェールオーバーの仕組み | 6 | [第5章](./05-Front-Doorフェールオーバーの仕組み/v1/v1-05-Front-Doorフェールオーバーの仕組み.pptx) |
| 障害注入と復旧運用 | 5 | [第6章](./06-障害注入と復旧運用/v1/v1-06-障害注入と復旧運用.pptx) |
| DRチェックリストとまとめ | 4 | [第7章](./07-DRチェックリストとまとめ/v1/v1-07-DRチェックリストとまとめ.pptx) |

統合版だけに表紙を置き、章単体に不要な表紙を追加していません。第3章のVM／AKSとCosmos DB／PostgreSQLの2枚は補足です。第5～6章は演習枠内の事前解説で、操作手順やデータストアの演習は含みません。

## デザインと修正元

- 指定ガイド：[design-template.md](../../../template/design-template.md)
- 生成基準：[generate-opus.template.js](../../../template/generate-opus.template.js)
- 配色、16:9の寸法、罫線、フッターは生成テンプレートに合わせています。指定フォルダにはPPTXテンプレートがないため、架空のロゴを追加しません。
- ガイドを優先し、日本語・英数字はYu Gothic UI、本文16pt以上、補足12pt以上、出典10pt以上とします。
- 出典は本文番号と同ページ下部の完全URLを対応付け、URL文字列だけにリンクを設定します。ノートにも完全URLを残します。
- 図形、接続線、ラベル、表は編集可能です。ページ番号は右下です。
- 各章の目的、範囲、投影本文、図表、出典、ノートは[chapters.json](./chapters.json)が修正元です。[生成コード](./generate-slides.js)はこの内容を直接読みます。
- 元の座学Markdownは解説資料として保持しています。スライド原稿を変更した場合も、座学の意味・範囲との整合を確認してください。
- 生成時の入力ハッシュと適用規則を `v1/build-manifest.json` に保存します。描画画像と検査記録は指定した検証ディレクトリへ保存し、配布資料とは分けます。

## 再生成と検証

Node.jsとPptxGenJS、Windows版PowerPoint、PythonのPillowとpypdfが必要です。Node.jsがPATHにない場合、生成スクリプトはVS Code内蔵Nodeランタイムを使用します。既存のグローバルPptxGenJSは `%APPDATA%\npm\node_modules` から参照します。

リポジトリルートで実行します。

```powershell
pwsh -File .\BCDR\座学\スライド\build-slides.ps1
pwsh -File .\BCDR\座学\スライド\render-slides.ps1 -VerificationDirectory C:\work\bcdr-verification
python .\BCDR\座学\スライド\verify-slides.py --verification-directory C:\work\bcdr-verification
```

既存のPPTX／PDFは既定で上書きしません。生成物を置き換える場合だけ `-Replace` を指定し、手作業で編集したファイルを上書きしないでください。別版は `-Version v2` で生成・描画し、検査にも `--version v2` を指定します。

```powershell
pwsh -File .\BCDR\座学\スライド\build-slides.ps1 -Version v2
```

`-Chapter 02` のように章を指定すると、その章のPPTXだけを生成します。全体の描画・検証は、全章と統合版を生成した後に行います。

描画スクリプトは、この処理で開いたプレゼンテーションだけを閉じます。共有中のPowerPointアプリケーションは終了しません。テキスト枠・表セルの収まりは3ptの測定差を許容して候補を検出し、画像でも確認します。

修正したページだけを再描画・再検査する場合は `-Pages 2,17` のように統合版のページ番号を指定します。全PDFは更新され、画像と文字枠の検査は指定ページに限定されます。初回は全ページを検査し、修正後の限定検査と分けて記録してください。
