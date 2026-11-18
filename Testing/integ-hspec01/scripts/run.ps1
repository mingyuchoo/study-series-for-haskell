param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ApplicationArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-CheckedCommand {
  param(
    [string]$Command,
    [string[]]$Arguments
  )

  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
  foreach ($tool in @("stack", "fourmolu", "hlint")) {
    if (-not (Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue)) {
      throw "Required command not found: $tool. See README.md for setup."
    }
  }

  $sourceFiles = @(
    Get-ChildItem -LiteralPath . -Filter *.hs -File
    Get-ChildItem -LiteralPath src, app, test -Filter *.hs -File -Recurse
  ) | ForEach-Object { $_.FullName }

  Write-Host "`n[1/5] Formatting Haskell sources"
  Invoke-CheckedCommand -Command "fourmolu" -Arguments (@("--mode", "inplace", "--config", "fourmolu.yaml") + $sourceFiles)

  Write-Host "`n[2/5] Linting Haskell sources"
  Invoke-CheckedCommand -Command "hlint" -Arguments $sourceFiles

  Write-Host "`n[3/5] Building"
  Invoke-CheckedCommand -Command "stack" -Arguments @("build", "--fast")

  Write-Host "`n[4/5] Testing"
  Invoke-CheckedCommand -Command "stack" -Arguments @("test", "--fast")

  Write-Host "`n[5/5] Running integ-hspec01-exe"
  Invoke-CheckedCommand -Command "stack" -Arguments (@("exec", "integ-hspec01-exe", "--") + $ApplicationArguments)
}
finally {
  Pop-Location
}
