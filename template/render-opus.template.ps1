<#
  スライド描画テンプレート（PowerPoint COM で PNG + PDF 出力）
  -------------------------------------------------------------------------
  使い方:
    1. このファイルを対象章へコピーする。
         docs/sections/<章フォルダ>/render-opus.ps1
    2. 既定では v1/ 配下の *.pptx を探して描画する。別バージョンや別ファイルは
       -Pptx で明示する。
    3. 実行:
         pwsh -File docs/sections/<章フォルダ>/render-opus.ps1
         pwsh -File docs/sections/<章フォルダ>/render-opus.ps1 -Pptx v2/v2-xx.pptx

  出力:
    - <OutDir>/<Prefix>-01.png ...（1600x900）
    - <Pptx> と同じ場所に同名 .pdf

  Prefix は指定しなければ pptx ファイル名の先頭2桁（例 v1-04-... → "04"）を使う。
  取得できない場合は "01" を使う。
#>
param(
  [string]$Pptx,
  [string]$OutDir,
  [string]$Prefix
)
$ErrorActionPreference = 'Stop'

# -Pptx 未指定なら v1/ 配下の pptx を1件自動選択
if (-not $Pptx) {
  $v1 = Join-Path $PSScriptRoot 'v1'
  $found = Get-ChildItem -Path $v1 -Filter '*.pptx' -File -ErrorAction SilentlyContinue |
    Sort-Object Name | Select-Object -First 1
  if (-not $found) { throw "pptx が見つかりません。-Pptx で指定してください（探索先: $v1）" }
  $Pptx = $found.FullName
}
$pptxPath = (Resolve-Path $Pptx).Path

# 出力ディレクトリ（既定は pptx と同じ場所の verification/）
if (-not $OutDir) { $OutDir = Join-Path (Split-Path $pptxPath -Parent) 'verification' }
[void][IO.Directory]::CreateDirectory($OutDir)
$OutDir = (Resolve-Path $OutDir).Path

# PNG プレフィックス（未指定ならファイル名の先頭2桁を使う）
if (-not $Prefix) {
  $base = [IO.Path]::GetFileNameWithoutExtension($pptxPath)
  $m = [regex]::Match($base, '(\d{2})')
  $Prefix = if ($m.Success) { $m.Groups[1].Value } else { '01' }
}

$ppt = New-Object -ComObject PowerPoint.Application
try {
  $deck = $ppt.Presentations.Open($pptxPath, $true, $false, $false)
  for ($i = 1; $i -le $deck.Slides.Count; $i++) {
    $png = Join-Path $OutDir ("{0}-{1:D2}.png" -f $Prefix, $i)
    $deck.Slides.Item($i).Export($png, 'PNG', 1600, 900)
  }
  $slideCount = $deck.Slides.Count
  $deck.SaveAs([IO.Path]::ChangeExtension($pptxPath, '.pdf'), 32)
  $deck.Close()
  "OK slides=$slideCount prefix=$Prefix out=$OutDir"
} finally {
  $ppt.Quit()
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($ppt) | Out-Null
}
