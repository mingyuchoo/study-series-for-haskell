param(
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'

if ($args.Count -gt 0) {
    throw 'Usage: .\scripts\run.ps1 [-CheckOnly]'
}

function Invoke-Tool {
    param(
        [string]$Name,
        [string[]]$Arguments
    )

    & $Name @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
    }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    foreach ($name in 'fourmolu', 'hlint', 'elm-format', 'elm', 'stack', 'npm.cmd', 'npx.cmd') {
        if (-not (Get-Command -Name $name -CommandType Application -ErrorAction SilentlyContinue)) {
            throw "Required command not found: $name"
        }
    }

    Write-Host 'Formatting Haskell and Elm...'
    Invoke-Tool 'fourmolu' @('--mode', 'inplace', '--config', 'fourmolu.yaml', 'Setup.hs', 'app', 'src', 'test')
    Invoke-Tool 'elm-format' @('--yes', 'web/src', 'web/tests')

    Write-Host 'Linting Haskell and checking Elm formatting...'
    Invoke-Tool 'hlint' @('--no-exit-code', 'Setup.hs', 'app', 'src', 'test')
    Invoke-Tool 'elm-format' @('--validate', 'web/src', 'web/tests')

    Write-Host 'Building Haskell and Elm...'
    Invoke-Tool 'stack' @('build')
    Push-Location -LiteralPath 'web'
    try {
        Invoke-Tool 'elm' @('make', 'src/Main.elm', '--output=elm.js')
    }
    finally {
        Pop-Location
    }

    Write-Host 'Testing Haskell and Elm...'
    Invoke-Tool 'stack' @('test')
    Push-Location -LiteralPath 'web'
    try {
        Invoke-Tool 'npm.cmd' @('ci')
        Invoke-Tool 'npx.cmd' @('--no-install', 'elm-test')
    }
    finally {
        Pop-Location
    }

    if (-not $CheckOnly) {
        Write-Host 'Starting GeneralService...'
        Invoke-Tool 'stack' @('run')
    }
}
finally {
    Pop-Location
}
