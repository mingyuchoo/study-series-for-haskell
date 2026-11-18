$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$applicationArguments = $args
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePaths = @('app', 'src', 'test', 'Setup.hs')

foreach ($tool in @('stack', 'fourmolu', 'hlint')) {
    if (-not (Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue)) {
        throw "Required tool not found: $tool. Install Stack and run: stack install fourmolu hlint"
    }
}

function Invoke-Step {
    param(
        [string]$Label,
        [string]$Command,
        [string[]]$CommandArguments
    )

    Write-Host "`n==> $Label"
    & $Command @CommandArguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

Push-Location -LiteralPath $projectRoot
try {
    $sourceFiles = @(
        Get-ChildItem -LiteralPath $sourcePaths -Recurse -File -Filter '*.hs' |
            Sort-Object FullName |
            ForEach-Object { $_.FullName }
    )

    Invoke-Step -Label 'Formatting' -Command 'fourmolu' -CommandArguments (@('--mode', 'inplace') + $sourceFiles)
    Invoke-Step -Label 'Linting' -Command 'hlint' -CommandArguments $sourcePaths
    Invoke-Step -Label 'Building' -Command 'stack' -CommandArguments @('build', '--test', '--no-run-tests')
    Invoke-Step -Label 'Testing' -Command 'stack' -CommandArguments @('test')
    Invoke-Step -Label 'Running' -Command 'stack' -CommandArguments (@('exec', 'tto-exe', '--') + $applicationArguments)
}
finally {
    Pop-Location
}
