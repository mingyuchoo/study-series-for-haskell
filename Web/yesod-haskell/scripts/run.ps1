[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ApplicationArguments = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-CheckedCommand {
    param(
        [string]$Command,
        [string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command failed with exit code $LASTEXITCODE."
    }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot

try {
    foreach ($tool in @('ghc', 'cabal', 'fourmolu', 'hlint')) {
        if (-not (Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue)) {
            throw "Required tool not found in PATH: $tool. See README.md for setup instructions."
        }
    }

    Write-Host "`n[1/5] Formatting Haskell sources"
    $sourceFiles = Get-ChildItem -LiteralPath 'src', 'app', 'test' -Recurse -File |
        Where-Object { $_.Extension -in '.hs', '.lhs' } |
        Sort-Object FullName

    foreach ($file in $sourceFiles) {
        Invoke-CheckedCommand -Command 'fourmolu' -Arguments @('--mode', 'inplace', '--config', 'fourmolu.yaml', $file.FullName)
    }

    Write-Host "`n[2/5] Linting Haskell sources"
    Invoke-CheckedCommand -Command 'hlint' -Arguments @('src', 'app', 'test')

    Write-Host "`n[3/5] Building all components"
    Invoke-CheckedCommand -Command 'cabal' -Arguments @('build', 'all', '--enable-tests')

    Write-Host "`n[4/5] Running tests"
    Invoke-CheckedCommand -Command 'cabal' -Arguments @('test', 'all', '--test-show-details=streaming')

    Write-Host "`n[5/5] Starting server at http://localhost:3000 (Ctrl+C to stop)"
    Invoke-CheckedCommand -Command 'cabal' -Arguments (@('run', 'yesod-haskell', '--') + $ApplicationArguments)
}
finally {
    Pop-Location
}
