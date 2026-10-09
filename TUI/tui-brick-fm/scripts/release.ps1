[CmdletBinding()]
param(
    [ValidateSet("auto", "nsis", "clean", "help")]
    [string]$Target = "auto"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$RootDir = Split-Path -Parent $PSScriptRoot
$ReleaseDir = Join-Path $RootDir 'dist/release'
$BuildBinDir = Join-Path $RootDir 'dist/build-bin'

if ($Target -eq "help") {
    Write-Host 'Usage: scripts/release.ps1 [auto|nsis|clean|help]'
    Write-Host 'Build a native Windows installer with Stack and NSIS 3 (makensis.exe).'
    Write-Host 'Output: dist/release/hfm-VERSION-windows-setup.exe'
    exit 0
}
if ($Target -eq 'clean') {
    $DistDir = [IO.Path]::GetFullPath((Join-Path $RootDir 'dist'))
    foreach ($path in @($DistDir, $ReleaseDir, $BuildBinDir)) {
        if (Test-Path -LiteralPath $path) {
            if ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Refusing to clean through a filesystem link: $path"
            }
        }
    }
    foreach ($path in @($ReleaseDir, $BuildBinDir)) {
        $absolute = [IO.Path]::GetFullPath($path)
        if (-not $absolute.StartsWith($DistDir + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove a path outside dist: $absolute"
        }
        if (Test-Path -LiteralPath $absolute) { Remove-Item -LiteralPath $absolute -Recurse -Force }
    }
    exit 0
}

if ($env:OS -ne 'Windows_NT') { throw 'This script builds Windows installers. Run it on Windows.' }
if (-not (Get-Command stack -ErrorAction SilentlyContinue)) {
    throw 'Stack is required. Install the Windows Haskell toolchain and add stack to PATH.'
}
$Nsis = Get-Command makensis -ErrorAction SilentlyContinue
if ($Nsis) {
    $Nsis = $Nsis.Name
}
else {
    $Nsis = @(
        foreach ($folder in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
            if ($folder) {
                $candidate = Join-Path $folder 'NSIS/makensis.exe'
                if (Test-Path -LiteralPath $candidate -PathType Leaf) { $candidate }
            }
        }
    ) | Select-Object -First 1
}
if (-not $Nsis) { throw 'NSIS 3 is required. Install NSIS or add makensis.exe to PATH.' }

$VersionLine = Select-String -LiteralPath (Join-Path $RootDir 'apps/hfm/package.yaml') -Pattern '^version:\s*(\d+\.\d+\.\d+\.\d+)\s*$'
if (-not $VersionLine -or @($VersionLine).Count -ne 1) { throw 'Expected one four-part version in apps/hfm/package.yaml' }
$Version = $VersionLine.Matches[0].Groups[1].Value
$Installer = Join-Path $ReleaseDir "hfm-$Version-windows-setup.exe"

Push-Location -LiteralPath $RootDir
try {
    New-Item -ItemType Directory -Path $BuildBinDir, $ReleaseDir -Force | Out-Null
    & stack build --copy-bins --local-bin-path $BuildBinDir
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (-not (Test-Path -LiteralPath (Join-Path $BuildBinDir 'hfm.exe') -PathType Leaf)) {
        throw "Built executable not found: $BuildBinDir/hfm.exe"
    }
    & $Nsis '/V2' "/DVERSION=$Version" "/DBIN_DIR=$BuildBinDir" "/DROOT_DIR=$RootDir" "/DOUTPUT=$Installer" (Join-Path $PSScriptRoot 'windows-installer.nsi')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (-not (Test-Path -LiteralPath $Installer -PathType Leaf)) { throw "Installer not found: $Installer" }
    Write-Host "Created $Installer"
}
finally {
    Pop-Location
}
exit 0
