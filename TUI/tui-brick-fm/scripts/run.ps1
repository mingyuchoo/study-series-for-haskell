[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("build", "test", "run", "all", "clean", "help")]
    [string]$Command = "run",

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Directories = @()
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$RootDir = Split-Path -Parent $PSScriptRoot

if ($Command -eq "help") {
    Write-Host "Usage: scripts/run.ps1 [build|test|run|all|clean|help] [LEFT_DIR] [RIGHT_DIR]"
    Write-Host "Build and run natively with Stack. Tests also require Python. Run in an interactive terminal."
    exit 0
}

if ($Command -notin @("run", "all") -and $Directories.Count -gt 0) {
    throw "Directory arguments are only accepted by run and all"
}
if ($Directories.Count -gt 2) {
    throw "At most two starting directories are supported"
}

if (-not (Get-Command stack -ErrorAction SilentlyContinue)) {
    throw "Stack is required. Install the Windows Haskell toolchain and add stack to PATH."
}

# Resolve relative arguments from the caller's location before entering the project.
$StartingDirectories = @(
    foreach ($directory in $Directories) {
        $item = Get-Item -LiteralPath $directory
        if (-not $item.PSIsContainer -or $item.PSProvider.Name -ne 'FileSystem') {
            throw "Not a filesystem directory: $directory"
        }
        $item.FullName
    }
)

function Invoke-Checked($Tool, [string[]]$Arguments) {
    & $Tool @Arguments
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$PreviousPythonUtf8 = $env:PYTHONUTF8
Push-Location -LiteralPath $RootDir
try {
    if ($Command -in @('build', 'all')) { Invoke-Checked stack @('build') }
    if ($Command -in @('test', 'all')) {
        if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
            throw "Python is required for architecture checks. Add python to PATH."
        }
        $env:PYTHONUTF8 = '1'
        Invoke-Checked python @('scripts/check-architecture.py')
        Invoke-Checked python @('scripts/test-architecture.py')
        Invoke-Checked stack @('test')
    }
    if ($Command -in @('run', 'all')) {
        Invoke-Checked stack (@('run', 'hfm-exe', '--') + $StartingDirectories)
    }
    if ($Command -eq 'clean') { Invoke-Checked stack @('clean') }
}
finally {
    Pop-Location
    $env:PYTHONUTF8 = $PreviousPythonUtf8
}
exit 0
