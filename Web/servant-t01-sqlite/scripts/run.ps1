$ErrorActionPreference = 'Stop'

function Invoke-Tool {
    param(
        [string] $Name,
        [string[]] $Arguments
    )

    & $Name @Arguments
    if ($LASTEXITCODE -ne 0) {
        Write-Host "$Name failed with exit code $LASTEXITCODE."
        exit $LASTEXITCODE
    }
}

foreach ($tool in 'fourmolu', 'hlint', 'stack') {
    if (-not (Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue)) {
        throw "Required command not found on PATH: $tool"
    }
}

Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try {
    Write-Host 'Formatting Haskell sources'
    $sourceFiles = @('Setup.hs')
    $sourceFiles += Get-ChildItem -LiteralPath 'app', 'src', 'test' -Filter '*.hs' -File -Recurse |
        ForEach-Object { $_.FullName }
    Invoke-Tool 'fourmolu' (@('--mode', 'inplace', '--config', 'fourmolu.yaml') + $sourceFiles)

    Write-Host 'Linting Haskell sources'
    Invoke-Tool 'hlint' @('Setup.hs', 'app', 'src', 'test')

    Write-Host 'Building'
    Invoke-Tool 'stack' @('build', '--fast')

    Write-Host 'Running tests'
    Invoke-Tool 'stack' @('test', '--fast')

    Write-Host 'Starting server on port 4000'
    Invoke-Tool 'stack' @('exec', 'servant-t01-sqlite-exe')
}
finally {
    Pop-Location
}
