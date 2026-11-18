$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

function Invoke-Tool {
    param(
        [string] $Name,
        [string[]] $Arguments
    )

    & $Name @Arguments
    if ($LASTEXITCODE -ne 0) {
        Write-Error "$Name failed with exit code $LASTEXITCODE." -ErrorAction Continue
        exit $LASTEXITCODE
    }
}

foreach ($tool in 'fourmolu', 'hlint', 'stack', 'npm.cmd') {
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
    Invoke-Tool 'fourmolu' (@('--mode', 'inplace', '--config', 'fourmolu.yaml', '--ghc-opt=-XGHC2024') + $sourceFiles)

    Write-Host 'Linting Haskell sources'
    Invoke-Tool 'hlint' @('--ignore-suggestions', 'Setup.hs', 'app', 'src', 'test')

    Write-Host 'Building Elm frontend'
    Invoke-Tool 'npm.cmd' @('ci')
    Invoke-Tool 'npm.cmd' @('run', 'build')

    Write-Host 'Building'
    Invoke-Tool 'stack' @('build', '--fast', '--test', '--no-run-tests')

    Write-Host 'Running tests'
    Invoke-Tool 'stack' @('test', '--fast')

    Write-Host 'Starting server on port 8000'
    Invoke-Tool 'stack' @('exec', 'servant-t03-clean-archi-exe')
}
finally {
    Pop-Location
}
