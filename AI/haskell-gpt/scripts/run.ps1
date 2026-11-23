$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

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

Push-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
try {
    foreach ($tool in @("fourmolu", "hlint", "stack")) {
        if (-not (Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue)) {
            [Console]::Error.WriteLine("Required command not found in PATH: $tool")
            exit 127
        }
    }

    Write-Host "`n[1/5] Formatting Haskell sources"
    $sourceFiles = @(Get-ChildItem -LiteralPath app, src, test -Filter "*.hs" -File -Recurse).FullName
    $formatArguments = @("--mode", "inplace", "--config", "fourmolu.yaml", "--ghc-opt=-XImportQualifiedPost")
    Invoke-CheckedCommand -Command fourmolu -Arguments ($formatArguments + $sourceFiles)

    Write-Host "`n[2/5] Linting Haskell sources"
    Invoke-CheckedCommand -Command hlint -Arguments @("--no-exit-code", "app", "src", "test")

    Write-Host "`n[3/5] Building HaskellGPT"
    Invoke-CheckedCommand -Command stack -Arguments @("build")

    Write-Host "`n[4/5] Testing HaskellGPT"
    Invoke-CheckedCommand -Command stack -Arguments @("test")

    Write-Host "`n[5/5] Running HaskellGPT"
    Invoke-CheckedCommand -Command stack -Arguments @("run", "HaskellGPT-exe")
}
finally {
    Pop-Location
}
