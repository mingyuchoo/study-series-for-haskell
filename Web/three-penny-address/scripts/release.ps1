$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$MakeCmd = if ($env:MAKE) { $env:MAKE } else { "make" }

function Get-PackageValue {
    param(
        [Parameter(Mandatory = $true)][string]$Key
    )

    $Line = Get-Content (Join-Path $ProjectRoot "package.yaml") |
        Where-Object { $_ -match "^$([regex]::Escape($Key)):\s*(.+)$" } |
        Select-Object -First 1

    if (-not $Line) {
        throw "Could not read '$Key' from package.yaml"
    }

    return ($Line -replace "^$([regex]::Escape($Key)):\s*", "").Trim()
}

function Invoke-Make {
    param(
        [Parameter(Mandatory = $true)][string]$Target
    )

    & $MakeCmd $Target
    if ($LASTEXITCODE -ne 0) {
        throw "make $Target failed with exit code $LASTEXITCODE"
    }
}

function Escape-Xml {
    param(
        [Parameter(Mandatory = $true)][string]$Value
    )

    return [System.Security.SecurityElement]::Escape($Value)
}

Set-Location $ProjectRoot

$PackageName = Get-PackageValue "name"
$Version = Get-PackageValue "version"
$Maintainer = Get-PackageValue "maintainer"
$LicenseName = Get-PackageValue "license"
$Executable = "$PackageName-exe"
$MsiVersionParts = $Version.Split(".") | Select-Object -First 3
$MsiVersion = ($MsiVersionParts -join ".")
$Arch = if ($env:PROCESSOR_ARCHITECTURE) { $env:PROCESSOR_ARCHITECTURE.ToLowerInvariant() } else { "x64" }

Invoke-Make "build"
Invoke-Make "test"
Invoke-Make "release"

$ReleaseDir = Join-Path $ProjectRoot "dist\release"
$StageDir = Join-Path $ProjectRoot "dist\msi-stage"
$InstallRoot = Join-Path $StageDir $PackageName

Remove-Item -Recurse -Force $StageDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $ReleaseDir, $InstallRoot | Out-Null

$ExeCandidates = @(
    (Join-Path $ProjectRoot "dist\bin\$Executable.exe"),
    (Join-Path $ProjectRoot "dist\bin\$Executable")
)
$ExeSource = $ExeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $ExeSource) {
    throw "Could not find release executable in dist\bin"
}

$InstalledExe = Join-Path $InstallRoot "$Executable.exe"
Copy-Item $ExeSource $InstalledExe
Copy-Item (Join-Path $ProjectRoot "static") (Join-Path $InstallRoot "static") -Recurse
Copy-Item (Join-Path $ProjectRoot "README.md") (Join-Path $InstallRoot "README.md")
Copy-Item (Join-Path $ProjectRoot "LICENSE") (Join-Path $InstallRoot "LICENSE")
Copy-Item (Join-Path $ProjectRoot "CHANGELOG.md") (Join-Path $InstallRoot "CHANGELOG.md")

$Launcher = Join-Path $InstallRoot "$PackageName.cmd"
@"
@echo off
cd /d "%~dp0"
"%~dp0$Executable.exe" %*
"@ | Set-Content -Encoding ASCII $Launcher

$WixPath = Get-Command wix -ErrorAction SilentlyContinue
if (-not $WixPath) {
    throw "WiX Toolset CLI was not found. Install WiX v4 and ensure 'wix' is on PATH."
}

$WxsPath = Join-Path $StageDir "package.wxs"
$MsiPath = Join-Path $ReleaseDir "$PackageName-$Version-windows-$Arch.msi"

$ExeXml = Escape-Xml $InstalledExe
$LauncherXml = Escape-Xml $Launcher
$StaticXml = Escape-Xml (Join-Path $InstallRoot "static\index.html")
$ReadmeXml = Escape-Xml (Join-Path $InstallRoot "README.md")
$LicenseXml = Escape-Xml (Join-Path $InstallRoot "LICENSE")
$ChangelogXml = Escape-Xml (Join-Path $InstallRoot "CHANGELOG.md")
$ManufacturerXml = Escape-Xml $Maintainer
$PackageNameXml = Escape-Xml $PackageName

@"
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs">
  <Package
      Name="$PackageNameXml"
      Manufacturer="$ManufacturerXml"
      Version="$MsiVersion"
      UpgradeCode="7A2D6D34-34E5-42B1-9D0A-75605C8E4D87"
      Scope="perMachine">
    <SummaryInformation Description="$PackageNameXml $Version installer" Manufacturer="$ManufacturerXml" />
    <MajorUpgrade DowngradeErrorMessage="A newer version of $PackageNameXml is already installed." />
    <MediaTemplate EmbedCab="yes" />

    <StandardDirectory Id="ProgramFilesFolder">
      <Directory Id="INSTALLFOLDER" Name="$PackageNameXml">
        <Component Id="MainExecutableComponent" Guid="A8918453-7E4C-4E47-97FA-2F44D4F024A7">
          <File Id="MainExecutableFile" Source="$ExeXml" KeyPath="yes" />
        </Component>
        <Component Id="LauncherComponent" Guid="B5B92A2E-6D1B-4F55-8D39-3572E42D57E8">
          <File Id="LauncherFile" Source="$LauncherXml" KeyPath="yes" />
        </Component>
        <Component Id="ReadmeComponent" Guid="7B3F3431-1F2D-4765-96BE-B9588C44648E">
          <File Id="ReadmeFile" Source="$ReadmeXml" KeyPath="yes" />
        </Component>
        <Component Id="LicenseComponent" Guid="5F3D4D70-7B0E-4F21-84E5-442839A5CB98">
          <File Id="LicenseFile" Source="$LicenseXml" KeyPath="yes" />
        </Component>
        <Component Id="ChangelogComponent" Guid="0F954191-053C-4614-9161-2D55274B0AE2">
          <File Id="ChangelogFile" Source="$ChangelogXml" KeyPath="yes" />
        </Component>
        <Directory Id="StaticFolder" Name="static">
          <Component Id="StaticIndexComponent" Guid="213F7AF2-FB09-41C1-8700-7C1E4AE39E0F">
            <File Id="StaticIndexFile" Source="$StaticXml" KeyPath="yes" />
          </Component>
        </Directory>
      </Directory>
    </StandardDirectory>

    <Feature Id="DefaultFeature" Title="$PackageNameXml" Level="1">
      <ComponentRef Id="MainExecutableComponent" />
      <ComponentRef Id="LauncherComponent" />
      <ComponentRef Id="ReadmeComponent" />
      <ComponentRef Id="LicenseComponent" />
      <ComponentRef Id="ChangelogComponent" />
      <ComponentRef Id="StaticIndexComponent" />
    </Feature>
  </Package>
</Wix>
"@ | Set-Content -Encoding UTF8 $WxsPath

& $WixPath.Source build $WxsPath -o $MsiPath
if ($LASTEXITCODE -ne 0) {
    throw "wix build failed with exit code $LASTEXITCODE"
}

Write-Host "Release artifact written to $MsiPath"
Write-Host "License: $LicenseName"
