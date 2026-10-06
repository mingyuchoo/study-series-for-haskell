[CmdletBinding()]
param(
    [ValidateSet("auto", "linux", "deb", "rpm", "dmg", "msi", "clean", "help")]
    [string]$Target = "auto"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ShellScript = Join-Path $ScriptDir "release.sh"

if ($Target -eq "help") {
    Write-Host "Usage: scripts/release.ps1 [auto|linux|deb|rpm|dmg|clean|help]"
    Write-Host "Windows uses WSL to build Linux packages. Native MSI is unsupported by this Unix-only app."
    exit 0
}
if ($Target -eq "msi") {
    throw "MSI is unsupported: this app uses System.Posix and /dev/tty. Build Linux packages in WSL instead."
}

if ($env:OS -eq "Windows_NT") {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        throw "WSL is required to package this Unix-only app."
    }
    $convertedScript = & wsl.exe wslpath -a -u $ShellScript
    if ($LASTEXITCODE -ne 0 -or -not $convertedScript) {
        throw "Could not resolve the release script path inside WSL"
    }
    $linuxScript = ($convertedScript | Select-Object -Last 1).Trim()
    & wsl.exe bash $linuxScript $Target
}
else {
    & bash $ShellScript $Target
}
exit $LASTEXITCODE
