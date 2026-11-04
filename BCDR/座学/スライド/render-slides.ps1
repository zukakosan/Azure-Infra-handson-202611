param(
  [ValidatePattern('^v\d+$')]
  [string]$Version = 'v1',
  [Parameter(Mandatory)]
  [string]$VerificationDirectory,
  [int[]]$Pages
)

$ErrorActionPreference = 'Stop'
$chapters = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'chapters.json') -Raw -Encoding utf8 | ConvertFrom-Json
[void][IO.Directory]::CreateDirectory($VerificationDirectory)
$VerificationDirectory = (Resolve-Path -LiteralPath $VerificationDirectory).Path
$jobs = @($chapters | ForEach-Object {
  @{
    Path = Join-Path $PSScriptRoot "$($_.folder)\$Version\$Version-$($_.folder).pptx"
    Images = $false
  }
})
$jobs += @{
  Path = Join-Path $PSScriptRoot "$Version\$Version-Azure-BCDR-座学.pptx"
  Images = $true
}
foreach ($job in $jobs) {
  if (-not (Test-Path -LiteralPath $job.Path -PathType Leaf)) { throw "PPTXがありません: $($job.Path)" }
}

$overflow = [Collections.Generic.List[object]]::new()
$decks = [Collections.Generic.List[object]]::new()

function Test-TextBounds($Shape, $SlideNumber, $ShapeLabel) {
  $frame = $Shape.TextFrame2
  if (-not $frame.HasText) { return }
  $availableHeight = $Shape.Height - $frame.MarginTop - $frame.MarginBottom
  $availableWidth = $Shape.Width - $frame.MarginLeft - $frame.MarginRight
  $height = $frame.TextRange.BoundHeight
  $width = $frame.TextRange.BoundWidth
  if ($height -gt $availableHeight + 3 -or $width -gt $availableWidth + 3) {
    $overflow.Add([pscustomobject]@{
      Slide = $SlideNumber; Shape = $ShapeLabel; Text = $frame.TextRange.Text
      Height = [Math]::Round($height, 2); AvailableHeight = [Math]::Round($availableHeight, 2)
      Width = [Math]::Round($width, 2); AvailableWidth = [Math]::Round($availableWidth, 2)
    })
  }
}

function Open-Presentation($Application, $Path) {
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
      return $Application.Presentations.Open($Path, -1, 0, 0)
    } catch [Runtime.InteropServices.COMException] {
      if ($_.Exception.HResult -ne -2147467260 -or $attempt -eq 3) { throw }
      Write-Warning "PowerPointが読み込みを中断しました。再試行 $attempt/2: $Path"
      Start-Sleep -Seconds 2
    }
  }
}

$ppt = New-Object -ComObject PowerPoint.Application
try {
  foreach ($job in $jobs) {
    $deck = $null
    try {
      $deck = Open-Presentation $ppt $job.Path
      if ($job.Images) {
        for ($i = 1; $i -le $deck.Slides.Count; $i++) {
          if ($Pages -and $i -notin $Pages) { continue }
          $slide = $deck.Slides.Item($i)
          for ($j = 1; $j -le $slide.Shapes.Count; $j++) {
            $shape = $slide.Shapes.Item($j)
            if ($shape.HasTable) {
              for ($r = 1; $r -le $shape.Table.Rows.Count; $r++) {
                for ($c = 1; $c -le $shape.Table.Columns.Count; $c++) {
                  Test-TextBounds $shape.Table.Cell($r, $c).Shape $i "table-$j-$r-$c"
                }
              }
            } elseif ($shape.HasTextFrame) {
              Test-TextBounds $shape $i $shape.Name
            }
          }
          $slide.Export((Join-Path $VerificationDirectory ('slide-{0:D2}.png' -f $i)), 'PNG', 1600, 900)
        }
      }
      $pdf = [IO.Path]::ChangeExtension($job.Path, '.pdf')
      $deck.SaveAs($pdf, 32)
      $decks.Add([pscustomobject]@{ Pptx = $job.Path; Pdf = $pdf; Slides = $deck.Slides.Count })
      "Rendered $($deck.Slides.Count) slides: $([IO.Path]::GetFileName($job.Path))"
    } finally {
      if ($null -ne $deck) {
        $deck.Close()
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($deck)
      }
    }
  }
} finally {
  # Only close presentations opened here; the PowerPoint application can be shared.
  [void][Runtime.InteropServices.Marshal]::ReleaseComObject($ppt)
}

$report = @{
  Renderer = 'Microsoft PowerPoint 16 COM'
  BoundsTolerancePoints = 3
  PagesChecked = if ($Pages) { $Pages } else { 'all' }
  Decks = @($decks)
  OverflowCandidates = @($overflow)
}
$reportName = if ($Pages) { 'render-report-pages.json' } else { 'render-report.json' }
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $VerificationDirectory $reportName) -Encoding utf8
if ($overflow.Count) {
  $overflow | Format-Table Slide, Shape, Height, AvailableHeight, Width, AvailableWidth -AutoSize
  throw "文字の収まりに確認が必要な箇所があります: $($overflow.Count)"
}
"PASS: PowerPointで指定範囲を描画、テキスト枠・表セルの収まりを確認。"
