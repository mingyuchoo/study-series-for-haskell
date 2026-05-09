[CmdletBinding()]
param(
    [ValidateSet("auto", "msi", "clean", "help")]
    [string]$Target = "auto"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Resolve-Path (Join-Path $ScriptDir "..")
$PackageName = "fzh"
$ExecutableName = "fzh-exe.exe"
$CommandName = "fzh.exe"
$ReleaseDir = Join-Path $RootDir "dist/release"
$StageDir = Join-Path $RootDir "dist/package-root-windows"
$WixDir = Join-Path $RootDir "dist/wix"

function Show-Usage {
    @"
Usage: ./scripts/release.ps1 [target]

Targets:
  auto   Build the Windows .msi installer (default)
  msi    Build the Windows .msi installer
  clean  Remove release staging directories
"@
}

function Get-PackageVersion {
    $line = Get-Content (Join-Path $RootDir "package.yaml") |
        Where-Object { $_ -match "^version:\s*" } |
        Select-Object -First 1

    if (-not $line) {
        throw "Could not read version from package.yaml"
    }

    return ($line -replace "^version:\s*", "").Trim()
}

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing required command: $Name"
    }
}

function Invoke-ReleaseBuild {
    Push-Location $RootDir
    try {
        & make release
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }
    finally {
        Pop-Location
    }
}

function Get-LocalInstallRoot {
    Push-Location $RootDir
    try {
        $path = & stack path --local-install-root
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
        return $path.Trim()
    }
    finally {
        Pop-Location
    }
}

function New-WixSource {
    param(
        [string]$Version,
        [string]$SourcePath,
        [ValidateSet("v3", "v4")]
        [string]$SchemaVersion
    )

    $wxsPath = Join-Path $WixDir "$PackageName.wxs"
    $readmePath = Join-Path $RootDir "README.md"
    $licensePath = Join-Path $RootDir "LICENSE"

    New-Item -ItemType Directory -Force -Path $WixDir | Out-Null

    if ($SchemaVersion -eq "v4") {
        $content = @"
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs">
  <Package
    Name="fzh"
    Manufacturer="Mingyu Choo"
    Version="$Version"
    UpgradeCode="9c4693c4-64e0-4b15-b65f-427459582d66"
    Scope="perMachine">
    <MajorUpgrade DowngradeErrorMessage="A newer version of fzh is already installed." />
    <MediaTemplate EmbedCab="yes" />
    <StandardDirectory Id="ProgramFilesFolder">
      <Directory Id="INSTALLFOLDER" Name="fzh">
        <Directory Id="INSTALLBINFOLDER" Name="bin">
          <Component Id="MainExecutable" Guid="0f5dce5d-9f8c-4ea0-9d7e-d706c2ec342d">
            <File Id="FzhExe" Source="$SourcePath" Name="fzh.exe" KeyPath="yes" />
          </Component>
        </Directory>
        <Directory Id="INSTALLDOCFOLDER" Name="doc">
          <Component Id="ReadmeFile" Guid="648cbdb8-d9e3-4384-a4e8-083295ba593c">
            <File Id="Readme" Source="$readmePath" Name="README.md" KeyPath="yes" />
          </Component>
          <Component Id="LicenseFile" Guid="3a2690e6-136f-47d6-8659-46cd0ccfedcf">
            <File Id="License" Source="$licensePath" Name="LICENSE" KeyPath="yes" />
          </Component>
        </Directory>
      </Directory>
    </StandardDirectory>
    <StandardDirectory Id="ProgramMenuFolder">
      <Directory Id="ApplicationProgramsFolder" Name="fzh">
        <Component Id="StartMenuShortcut" Guid="dfc3c6ea-90c2-4ef0-9198-d56886c3030d">
          <Shortcut
            Id="ApplicationStartMenuShortcut"
            Name="fzh"
            Description="Terminal fuzzy finder"
            Target="[INSTALLBINFOLDER]fzh.exe"
            WorkingDirectory="INSTALLBINFOLDER" />
          <RemoveFolder Id="RemoveApplicationProgramsFolder" On="uninstall" />
          <RegistryValue Root="HKLM" Key="Software\MingyuChoo\fzh" Name="installed" Type="integer" Value="1" KeyPath="yes" />
        </Component>
      </Directory>
    </StandardDirectory>
    <Feature Id="ProductFeature" Title="fzh" Level="1">
      <ComponentRef Id="MainExecutable" />
      <ComponentRef Id="ReadmeFile" />
      <ComponentRef Id="LicenseFile" />
      <ComponentRef Id="StartMenuShortcut" />
    </Feature>
  </Package>
</Wix>
"@
    }
    else {
        $content = @"
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Product
    Id="*"
    Name="fzh"
    Language="1033"
    Version="$Version"
    Manufacturer="Mingyu Choo"
    UpgradeCode="9c4693c4-64e0-4b15-b65f-427459582d66">
    <Package InstallerVersion="500" Compressed="yes" InstallScope="perMachine" />
    <MajorUpgrade DowngradeErrorMessage="A newer version of fzh is already installed." />
    <MediaTemplate EmbedCab="yes" />
    <Directory Id="TARGETDIR" Name="SourceDir">
      <Directory Id="ProgramFilesFolder">
        <Directory Id="INSTALLFOLDER" Name="fzh">
          <Directory Id="INSTALLBINFOLDER" Name="bin">
            <Component Id="MainExecutable" Guid="0f5dce5d-9f8c-4ea0-9d7e-d706c2ec342d">
              <File Id="FzhExe" Source="$SourcePath" Name="fzh.exe" KeyPath="yes" />
            </Component>
          </Directory>
          <Directory Id="INSTALLDOCFOLDER" Name="doc">
            <Component Id="ReadmeFile" Guid="648cbdb8-d9e3-4384-a4e8-083295ba593c">
              <File Id="Readme" Source="$readmePath" Name="README.md" KeyPath="yes" />
            </Component>
            <Component Id="LicenseFile" Guid="3a2690e6-136f-47d6-8659-46cd0ccfedcf">
              <File Id="License" Source="$licensePath" Name="LICENSE" KeyPath="yes" />
            </Component>
          </Directory>
        </Directory>
      </Directory>
      <Directory Id="ProgramMenuFolder">
        <Directory Id="ApplicationProgramsFolder" Name="fzh">
          <Component Id="StartMenuShortcut" Guid="dfc3c6ea-90c2-4ef0-9198-d56886c3030d">
            <Shortcut
              Id="ApplicationStartMenuShortcut"
              Name="fzh"
              Description="Terminal fuzzy finder"
              Target="[INSTALLBINFOLDER]fzh.exe"
              WorkingDirectory="INSTALLBINFOLDER" />
            <RemoveFolder Id="RemoveApplicationProgramsFolder" On="uninstall" />
            <RegistryValue Root="HKLM" Key="Software\MingyuChoo\fzh" Name="installed" Type="integer" Value="1" KeyPath="yes" />
          </Component>
        </Directory>
      </Directory>
    </Directory>
    <Feature Id="ProductFeature" Title="fzh" Level="1">
      <ComponentRef Id="MainExecutable" />
      <ComponentRef Id="ReadmeFile" />
      <ComponentRef Id="LicenseFile" />
      <ComponentRef Id="StartMenuShortcut" />
    </Feature>
  </Product>
</Wix>
"@
    }

    Set-Content -Path $wxsPath -Value $content -Encoding UTF8
    return $wxsPath
}

function Build-Msi {
    Require-Command make
    Require-Command stack
    Invoke-ReleaseBuild

    $version = Get-PackageVersion
    $installRoot = Get-LocalInstallRoot
    $builtExe = Join-Path $installRoot "bin/$ExecutableName"
    $stageBin = Join-Path $StageDir "bin/$CommandName"
    $msiPath = Join-Path $ReleaseDir "$PackageName-$version.msi"

    if (-not (Test-Path $builtExe)) {
        throw "Built executable not found: $builtExe"
    }

    Remove-Item -Recurse -Force $StageDir, $WixDir -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $stageBin), $ReleaseDir | Out-Null
    Copy-Item $builtExe $stageBin

    if (Get-Command wix -ErrorAction SilentlyContinue) {
        $wxsPath = New-WixSource -Version $version -SourcePath $stageBin -SchemaVersion "v4"
        & wix build $wxsPath -o $msiPath
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }
    elseif ((Get-Command candle -ErrorAction SilentlyContinue) -and (Get-Command light -ErrorAction SilentlyContinue)) {
        $wxsPath = New-WixSource -Version $version -SourcePath $stageBin -SchemaVersion "v3"
        $wixObj = Join-Path $WixDir "$PackageName.wixobj"
        & candle -out $wixObj $wxsPath
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
        & light -out $msiPath $wixObj
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }
    else {
        throw "Missing required command: wix, or both candle and light"
    }

    Write-Host "Created $msiPath"
}

switch ($Target) {
    "auto" { Build-Msi }
    "msi" { Build-Msi }
    "clean" { Remove-Item -Recurse -Force $ReleaseDir, $StageDir, $WixDir -ErrorAction SilentlyContinue }
    "help" { Show-Usage }
}
