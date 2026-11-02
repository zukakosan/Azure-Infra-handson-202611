param(
  [string]$Chapter,
  [ValidatePattern('^v\d+$')]
  [string]$Version = 'v1'
)

$ErrorActionPreference = 'Stop'
$slideDirectory = $PSScriptRoot
$projectRoot = Resolve-Path (Join-Path $slideDirectory '..\..\..')
$renderTemplate = Join-Path $projectRoot 'template\render-opus.template.ps1'
$chapters = Get-Content -LiteralPath (Join-Path $slideDirectory 'chapters.json') -Raw | ConvertFrom-Json

if (-not (Test-Path -LiteralPath $renderTemplate -PathType Leaf)) {
  throw "Render template not found: $renderTemplate"
}

$selected = if ($Chapter) {
  @($chapters | Where-Object { $_.id -eq $Chapter })
} else {
  @($chapters)
}
if ($selected.Count -eq 0) {
  throw "Unknown chapter: $Chapter"
}

foreach ($item in $selected) {
  $folder = Join-Path $slideDirectory $item.folder
  $versionFolder = Join-Path $folder $Version
  $pptx = Join-Path $versionFolder ("{0}-{1}.pptx" -f $Version, $item.folder)
  if (-not (Test-Path -LiteralPath $pptx -PathType Leaf)) {
    throw "PPTX not found; generate it first: $pptx"
  }
  $outDir = Join-Path $versionFolder 'verification'
  & $renderTemplate -Pptx $pptx -OutDir $outDir -Prefix $item.id
}
