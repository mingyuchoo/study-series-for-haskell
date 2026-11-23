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
        Require-Command pkg-config
        & pkg-config --exists --print-errors gobject-introspection-1.0 gtk4
        if ($LASTEXITCODE -ne 0) {
            throw "GTK 4 and GObject Introspection development packages are required."
        }
    }

    if ($Action -in "all", "format", "lint") {
        $sourceFiles = @(
            Get-ChildItem -LiteralPath . -Filter "*.hs" -File
            Get-ChildItem -LiteralPath app, src, test -Filter "*.hs" -File -Recurse
        ).FullName
    }

    if ($Action -in "all", "format") {
        Write-Host "`n==> Formatting Haskell sources"
        Invoke-CheckedCommand fourmolu (@("--mode", "inplace", "--config", "fourmolu.yaml") + $sourceFiles)
        Invoke-CheckedCommand stylish-haskell (@("-c", ".stylish-haskell.yaml", "-i") + $sourceFiles)
    }
    if ($Action -in "all", "lint") {
        Write-Host "`n==> Linting Haskell sources"
        Invoke-CheckedCommand hlint $sourceFiles
    }
    if ($Action -in "all", "build") {
        Write-Host "`n==> Building GiGtkApp"
        Invoke-CheckedCommand $stackCommand @("build", "--fast")
    }
    if ($Action -in "all", "test") {
        Write-Host "`n==> Testing GiGtkApp"
        Invoke-CheckedCommand $stackCommand @("test", "--fast")
    }
    if ($Action -in "all", "run") {
        Write-Host "`n==> Running GiGtkApp-exe"
        Invoke-CheckedCommand $stackCommand @("run", "GiGtkApp-exe")
    }
}
finally {
    Pop-Location
}
