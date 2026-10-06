[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("build", "test", "run", "all", "clean", "help")]
    [string]$Command = "run",

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Directories = @()
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ShellScript = Join-Path $ScriptDir "run.sh"

if ($Command -eq "help") {
    Write-Host "Usage: scripts/run.ps1 [build|test|run|all|clean|help] [LEFT_DIR] [RIGHT_DIR]"
    Write-Host "On Windows, commands run inside WSL because the app uses /dev/tty."
    exit 0
}

if ($Command -notin @("run", "all") -and $Directories.Count -gt 0) {
    throw "Directory arguments are only accepted by run and all"
}
if ($Directories.Count -gt 2) {
    throw "At most two starting directories are supported"
}

if ($env:OS -eq "Windows_NT") {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        throw "WSL is required: the app uses Unix /dev/tty. Install WSL and Stack inside it."
    }

    $convertedScript = & wsl.exe wslpath -a -u $ShellScript
    if ($LASTEXITCODE -ne 0 -or -not $convertedScript) {
        throw "Could not resolve the script path inside WSL"
    }
    $linuxScript = ($convertedScript | Select-Object -Last 1).Trim()

    $linuxDirectories = @(
        foreach ($directory in $Directories) {
            $resolved = (Resolve-Path -LiteralPath $directory).Path
            $convertedPath = & wsl.exe wslpath -a -u $resolved
            if ($LASTEXITCODE -ne 0 -or -not $convertedPath) {
                throw "Could not resolve directory inside WSL: $directory"
            }
            ($convertedPath | Select-Object -Last 1).Trim()
        }
    )
    & wsl.exe bash $linuxScript $Command @linuxDirectories
}
else {
    & bash $ShellScript $Command @Directories
}
exit $LASTEXITCODE
