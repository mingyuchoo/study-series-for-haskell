[CmdletBinding()]
param(
    [switch]$SkipRun,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

if ($Help) {
    Write-Output @'
Usage: ./scripts/run.ps1 [-SkipRun] [-Help]

Format, lint, build, test, and run the application.
  -SkipRun  Stop after tests without starting the server.
  -Help     Show this help.

Required commands: stack, fourmolu, hlint
'@
    exit 0
}

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
    foreach ($requiredCommand in @('stack', 'fourmolu', 'hlint')) {
        if (-not (Get-Command $requiredCommand -CommandType Application -ErrorAction SilentlyContinue)) {
            [Console]::Error.WriteLine("Required command not found: $requiredCommand")
            [Console]::Error.WriteLine('Install Stack, then install development tools with: stack install fourmolu hlint')
            exit 127
        }
    }

    $sourceFiles = @(
        Get-ChildItem -LiteralPath $projectRoot -Filter '*.hs' -File
        foreach ($sourceDirectory in @('src', 'app', 'test')) {
            Get-ChildItem -LiteralPath (Join-Path $projectRoot $sourceDirectory) -Filter '*.hs' -File -Recurse
        }
    ) | Select-Object -ExpandProperty FullName

    Write-Host "`n[1/5] Formatting Haskell sources"
    foreach ($sourceFile in $sourceFiles) {
        Invoke-CheckedCommand -Command 'fourmolu' -Arguments @('--mode', 'inplace', '--config', (Join-Path $projectRoot 'fourmolu.yaml'), $sourceFile)
    }

    Write-Host "`n[2/5] Linting Haskell sources"
    Invoke-CheckedCommand -Command 'hlint' -Arguments (@('--language=GHC2024') + $sourceFiles)

    Write-Host "`n[3/5] Building application and tests"
    Invoke-CheckedCommand -Command 'stack' -Arguments @('build', '--test', '--no-run-tests')

    Write-Host "`n[4/5] Running tests"
    Invoke-CheckedCommand -Command 'stack' -Arguments @('test')

    if ($SkipRun) {
        Write-Host "`nChecks completed. Server startup skipped."
    }
    else {
        Write-Host "`n[5/5] Starting server at http://localhost:8000 (Ctrl+C to stop)"
        Invoke-CheckedCommand -Command 'stack' -Arguments @('exec', 'warp-t03-clean-archi-exe')
    }
}
finally {
    Pop-Location
}
