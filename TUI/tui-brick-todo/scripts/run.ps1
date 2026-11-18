$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$applicationArguments = $args
$projectRoot = Split-Path -Parent $PSScriptRoot

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
        Get-ChildItem -LiteralPath 'app', 'src', 'test' -Recurse -File -Filter '*.hs' |
            Sort-Object FullName |
            ForEach-Object { $_.FullName }
        (Get-Item -LiteralPath 'Setup.hs').FullName
    )

    Invoke-Step -Label 'Formatting' -Command 'fourmolu' -CommandArguments (@('--mode', 'inplace') + $sourceFiles)
    Invoke-Step -Label 'Linting' -Command 'hlint' -CommandArguments @('app', 'src', 'test', 'Setup.hs')
    Invoke-Step -Label 'Building' -Command 'stack' -CommandArguments @('build', '--test', '--no-run-tests')
    Invoke-Step -Label 'Testing' -Command 'stack' -CommandArguments @('test')
    Invoke-Step -Label 'Running' -Command 'stack' -CommandArguments (@('exec', 'tto-exe', '--') + $applicationArguments)
}
finally {
    Pop-Location
}
