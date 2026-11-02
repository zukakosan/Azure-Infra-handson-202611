# 座学の章別スライド

5つの座学Markdownを、それぞれ独立したPowerPointとPDFにしています。本文は各章の到達目標に合わせて再構成し、原稿の例、条件、留保を保っています。

## デザイン基準

- デザインガイド: `../../../template/design-template.md`
- 生成・描画テンプレート: `../../../template/generate-opus.template.js`、`../../../template/render-opus.template.ps1`
- 本ガイドの規則がテンプレートの既定値と異なる場合は、デザインガイドを優先します。日本語・英数字はYu Gothic UI、本文16pt以上、補足12pt以上、出典10pt以上です。
- URLを省略せず、本文中の参照番号とスライド下部の番号付きURLを対応させます。ハイパーリンクはURL文字列にだけ設定し、完全なURLを講師ノートにも保存します。
- すべての図表は編集可能なPowerPoint要素です。スライド番号は表紙を含めて右下に配置します。

## 再生成

Node.jsとPptxGenJSが必要です。PowerPointでPDFとPNGを描画するにはWindows版PowerPointも必要です。

```powershell
$env:NODE_PATH = Join-Path $env:APPDATA 'npm\node_modules'
node .\Network\座学\スライド\generate-chapters.js
pwsh -File .\Network\座学\スライド\render-chapters.ps1
```

章を1つだけ生成・描画する場合は、章番号（`00`〜`04`）を指定します。既存の成果物は保護されるため、生成コードを変更して出力を置き換える場合に限り、`--replace`を明示してください。描画スクリプトは、同じ章番号の引数を受け取ります。

```powershell
node .\Network\座学\スライド\generate-chapters.js 01
node .\Network\座学\スライド\generate-chapters.js 01 --replace
pwsh -File .\Network\座学\スライド\render-chapters.ps1 -Chapter 01
```

バージョンを分けて生成・描画する場合は、`--version`と`-Version`を指定します。既存の`v1`を保持したまま、新しい`v2`を作成できます。

```powershell
node .\Network\座学\スライド\generate-chapters.js --version v2
pwsh -File .\Network\座学\スライド\render-chapters.ps1 -Version v2
```

各章の構成・投影内容・出典は`chapters.json`が正本です。PPTXとPDF、描画確認用PNGは各バージョンのフォルダーに出力します。章の目的と範囲は、隣接する座学Markdownと[講義アジェンダ](../../azure-routing-workshop-agenda.md)に対応しています。
