$ErrorActionPreference = "Stop"
$ApplicationArguments = $args
if ($ApplicationArguments.Count -eq 0) {
    $ApplicationArguments = @("-o", "output.svg", "-w", "400")
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

    Write-Host "`n[3/5] Building DiagramsDemo03"
    Invoke-CheckedCommand -Command stack -Arguments @("build")

    Write-Host "`n[4/5] Testing DiagramsDemo03"
    Invoke-CheckedCommand -Command stack -Arguments @("test")

    Write-Host "`n[5/5] Running DiagramsDemo03"
    Invoke-CheckedCommand -Command stack -Arguments (@("run", "DiagramsDemo03-exe", "--") + $ApplicationArguments)
}
finally {
    Pop-Location
}
