$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,
        [Parameter(Mandatory = $true)]
        [string[]]$CommandArguments
    )

    & $Executable @CommandArguments
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot

try {
    foreach ($tool in @('stack', 'fourmolu', 'hlint')) {
        if (-not (Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue)) {
            throw "Required tool not found in PATH: $tool"
        }
    }

    $sourceFiles = @(
        Get-ChildItem -LiteralPath $projectRoot -File -Filter '*.hs'
        foreach ($sourceDirectory in @('app', 'src', 'test')) {
            Get-ChildItem -LiteralPath (Join-Path $projectRoot $sourceDirectory) -Recurse -File -Filter '*.hs'
        }
    ) | Select-Object -ExpandProperty FullName

    Write-Host "`n[1/5] Formatting Haskell sources"
    foreach ($sourceFile in $sourceFiles) {
        Invoke-CheckedCommand -Executable 'fourmolu' -CommandArguments @(
            '--mode', 'inplace', '--config', 'fourmolu.yaml', $sourceFile
        )
    }

    Write-Host "`n[2/5] Linting Haskell sources"
    Invoke-CheckedCommand -Executable 'hlint' -CommandArguments $sourceFiles

    Write-Host "`n[3/5] Building"
    Invoke-CheckedCommand -Executable 'stack' -CommandArguments @('build')

    Write-Host "`n[4/5] Testing"
    Invoke-CheckedCommand -Executable 'stack' -CommandArguments @('test')

    Write-Host "`n[5/5] Starting server at http://localhost:4000 (Ctrl+C to stop)"
    Invoke-CheckedCommand -Executable 'stack' -CommandArguments (@(
        'exec', 'warp-t00-init-exe', '--'
    ) + $args)
}
finally {
    Pop-Location
}
