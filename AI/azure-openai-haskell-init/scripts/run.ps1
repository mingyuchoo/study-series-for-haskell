$ErrorActionPreference = "Stop"
$applicationArguments = $args

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

    $sourceDirs = @("app", "src")
    if (Test-Path -LiteralPath test -PathType Container) {
        $sourceDirs += "test"
    }
    $sourceFiles = (Get-ChildItem -LiteralPath $sourceDirs -Filter "*.hs" -File -Recurse).FullName

    Write-Host "`n[1/5] Formatting Haskell sources"
    Invoke-CheckedCommand -Command fourmolu -Arguments (@("--mode", "inplace", "--config", "fourmolu.yaml") + $sourceFiles)

    Write-Host "`n[2/5] Linting Haskell sources"
    Invoke-CheckedCommand -Command hlint -Arguments (@("--no-exit-code") + $sourceDirs)

    Write-Host "`n[3/5] Building project"
    Invoke-CheckedCommand -Command stack -Arguments @("build")

    Write-Host "`n[4/5] Testing project"
    Invoke-CheckedCommand -Command stack -Arguments @("test")

    Write-Host "`n[5/5] Running application"
    Invoke-CheckedCommand -Command stack -Arguments (@("run", "azure-openai-haskell-init-exe", "--") + $applicationArguments)
}
finally {
    Pop-Location
}
