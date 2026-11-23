$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

function Invoke-Stage {
    param(
        [string] $Command,
        [string[]] $Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command failed with exit code $LASTEXITCODE."
    }
}

Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try {
    foreach ($tool in 'fourmolu', 'stylish-haskell', 'hlint', 'stack') {
        if (-not (Get-Command -Name $tool -CommandType Application -ErrorAction SilentlyContinue)) {
            throw "Required command not found: $tool"
        }
    }

    Write-Host 'Formatting Haskell sources...'
    $files = @(
        Get-Item -LiteralPath 'Setup.hs'
        Get-ChildItem -LiteralPath 'src', 'app', 'test' -Recurse -File -Filter '*.hs'
    )
    foreach ($file in $files) {
        Invoke-Stage fourmolu @('--ghc-opt=-XImportQualifiedPost', '--mode', 'inplace', '--config', 'fourmolu.yaml', $file.FullName)
        Invoke-Stage stylish-haskell @('-c', '.stylish-haskell.yaml', '-i', $file.FullName)
    }

    Write-Host 'Linting Haskell sources...'
    Invoke-Stage hlint @('--no-exit-code', 'Setup.hs', 'src', 'app', 'test')

    Write-Host 'Building...'
    Invoke-Stage stack @('build')

    Write-Host 'Running tests...'
    Invoke-Stage stack @('test', '--rerun-tests')

    Write-Host 'Starting the server...'
    Invoke-Stage stack (@('exec', 'postgresql-simple-init-exe', '--') + $args)
}
finally {
    Pop-Location
}
