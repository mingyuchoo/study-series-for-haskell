$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

function Show-Usage {
    Write-Host "Usage: run.ps1 [all|format|lint|build|test|run]"
    Write-Host "Default: format, lint, build, test, then run."
}

function Require-Command {
    param([string]$Command)

    if (-not (Get-Command -Name $Command -CommandType Application -ErrorAction SilentlyContinue)) {
        [Console]::Error.WriteLine("Required command not found in PATH: $Command")
        exit 127
    }
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

if ($args.Count -gt 1) {
    Show-Usage
    exit 2
}
$Action = "all"
if ($args.Count -eq 1) {
    $Action = $args[0]
}
if ($Action -in "-h", "--help", "help") {
    Show-Usage
    exit 0
}
if ($Action -notin "all", "format", "lint", "build", "test", "run") {
    Show-Usage
    exit 2
}

$stackCommand = "stack"
if ($env:STACK) {
    $stackCommand = $env:STACK
}

Push-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
try {
    if ($Action -in "all", "format") {
        Require-Command fourmolu
        Require-Command stylish-haskell
    }

    if ($Action -in "all", "lint") {
        Require-Command hlint
    }

    if ($Action -in "all", "build", "test", "run") {
        Require-Command $stackCommand
    }

    if ($Action -in "all", "format", "lint") {
        $moduleFiles = @(
            foreach ($directory in "app", "src", "test") {
                if (Test-Path -LiteralPath $directory -PathType Container) {
                    Get-ChildItem -LiteralPath $directory -Filter "*.hs" -File -Recurse
                }
            }
        ).FullName
        $sourceFiles = @(
            (Get-ChildItem -LiteralPath . -Filter "*.hs" -File).FullName
            $moduleFiles
        )
    }

    if ($Action -in "all", "format") {
        Write-Host "`n==> Formatting Haskell sources"
        Invoke-CheckedCommand fourmolu (@("--mode", "inplace", "--config", "fourmolu.yaml") + $sourceFiles)
        Invoke-CheckedCommand stylish-haskell (@("-c", ".stylish-haskell.yaml", "-i") + $moduleFiles)
    }
    if ($Action -in "all", "lint") {
        Write-Host "`n==> Linting Haskell sources"
        Invoke-CheckedCommand hlint $sourceFiles
    }
    if ($Action -in "all", "build") {
        Write-Host "`n==> Building MonomerApp"
        Invoke-CheckedCommand $stackCommand @("build", "--fast", "MonomerApp:exe:app")
    }
    if ($Action -in "all", "test") {
        Write-Host "`n==> Testing MonomerApp"
        Invoke-CheckedCommand $stackCommand @("test", "--fast")
    }
    if ($Action -in "all", "run") {
        Write-Host "`n==> Running MonomerApp:exe:app"
        Invoke-CheckedCommand $stackCommand @("run", "MonomerApp:exe:app")
    }
}
finally {
    Pop-Location
}
