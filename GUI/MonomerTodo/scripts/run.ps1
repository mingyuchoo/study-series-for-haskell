param(
  [ValidateSet("build", "test", "run", "all", "help")]
  [string]$Command = "run",
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$MakeArgs
)

$ErrorActionPreference = "Stop"
$RootDir = Resolve-Path (Join-Path $PSScriptRoot "..")

function Show-Usage {
  @"
Usage: scripts/run.ps1 [build|test|run|all|help]

Commands:
  build   Build the application through Makefile
  test    Run tests through Makefile
  run     Run the application through Makefile
  all     Build and test through Makefile
  help    Show this help
"@ | Write-Host
}

if ($Command -eq "help") {
  Show-Usage
  exit 0
}

$make = Get-Command "make" -ErrorAction SilentlyContinue
if (-not $make) {
  $make = Get-Command "mingw32-make" -ErrorAction SilentlyContinue
}
if (-not $make) {
  throw "Required command not found: make or mingw32-make"
}

Push-Location $RootDir
try {
  & $make.Source $Command @MakeArgs
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}
finally {
  Pop-Location
}
