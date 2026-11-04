param(
  [ValidatePattern('^\d{2}$')]
  [string]$Chapter,
  [ValidatePattern('^v\d+$')]
  [string]$Version = 'v1',
  [switch]$Replace
)

$ErrorActionPreference = 'Stop'
$node = Get-Command node -ErrorAction SilentlyContinue
$runtime = if ($node) { $node.Source } else {
  Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\Code.exe'
}
if (-not (Test-Path -LiteralPath $runtime -PathType Leaf)) {
  throw 'Node.js または VS Code 内蔵 Node ランタイムが必要です。'
}

$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName = $runtime
$start.UseShellExecute = $false
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$start.WorkingDirectory = $PSScriptRoot
if (-not $node) { $start.Environment['ELECTRON_RUN_AS_NODE'] = '1' }
$globalModules = Join-Path $env:APPDATA 'npm\node_modules'
$start.Environment['NODE_PATH'] = if ($env:NODE_PATH) {
  "$($env:NODE_PATH);$globalModules"
} else { $globalModules }
$start.ArgumentList.Add((Join-Path $PSScriptRoot 'generate-slides.js'))
$start.ArgumentList.Add('--version')
$start.ArgumentList.Add($Version)
if ($Chapter) { $start.ArgumentList.Add($Chapter) }
if ($Replace) { $start.ArgumentList.Add('--replace') }

$process = [Diagnostics.Process]::new()
try {
  $process.StartInfo = $start
  [void]$process.Start()
  $stdout = $process.StandardOutput.ReadToEndAsync()
  $stderr = $process.StandardError.ReadToEndAsync()
  $process.WaitForExit()
  $stdout.GetAwaiter().GetResult() | Write-Output
  $errorText = $stderr.GetAwaiter().GetResult()
  if ($errorText) { Write-Output $errorText }
  if ($process.ExitCode -ne 0) { throw "スライド生成が失敗しました（exit=$($process.ExitCode)）。" }
} finally {
  $process.Dispose()
}
