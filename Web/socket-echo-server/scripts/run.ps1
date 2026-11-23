$ErrorActionPreference = "Stop"
$applicationArguments = $args

function Invoke-CheckedCommand {
    param(
        [string]$Command,
        [string[]]$Arguments
    )

    $PSNativeCommandUseErrorActionPreference = $false
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

Push-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
try {
    foreach ($tool in @("fourmolu", "hlint", "stack")) {
        if (-not (Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue)) {
            throw "Required command not found in PATH: $tool"
        }
    }

    $sourceFiles = @(
        Get-ChildItem -LiteralPath . -Filter "*.hs" -File
        Get-ChildItem -LiteralPath app, src, test -Filter "*.hs" -File -Recurse
    ).FullName

    Write-Host "`n[1/5] Formatting Haskell sources"
    Invoke-CheckedCommand -Command fourmolu -Arguments (@("--mode", "inplace", "--config", "fourmolu.yaml") + $sourceFiles)

    Write-Host "`n[2/5] Linting Haskell sources"
    Invoke-CheckedCommand -Command hlint -Arguments $sourceFiles

    Write-Host "`n[3/5] Building socket-echo-server"
    Invoke-CheckedCommand -Command stack -Arguments @("build", "--test", "--no-run-tests")

    Write-Host "`n[4/5] Testing socket-echo-server"
    Invoke-CheckedCommand -Command stack -Arguments @("test")

    Write-Host "`n[5/5] Running socket-echo-server"
    Invoke-CheckedCommand -Command stack -Arguments (@("exec", "socket-echo-server-exe", "--") + $applicationArguments)
}
finally {
    Pop-Location
}
