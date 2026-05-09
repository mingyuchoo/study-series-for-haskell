[CmdletBinding()]
param(
    [ValidateSet("build", "test", "run", "all", "clean", "help")]
    [string]$Command = "run"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Resolve-Path (Join-Path $ScriptDir "..")

function Show-Usage {
    @"
Usage: ./scripts/run.ps1 <command>

Commands:
  build   Build the project with Makefile
  test    Run tests with Makefile
  run     Build and run the app with Makefile
  all     Clean, setup, build, test, and run with Makefile
  clean   Clean build artifacts with Makefile
"@
}

if ($Command -eq "help") {
    Show-Usage
    exit 0
}

Push-Location $RootDir
try {
    & make $Command
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}
