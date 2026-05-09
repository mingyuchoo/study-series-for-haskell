param(
  [string]$Version = $(if ($env:VERSION) { $env:VERSION } else { "0.1.0" }),
  [string]$Manufacturer = $(if ($env:MANUFACTURER) { $env:MANUFACTURER } else { "MonomerTodo" }),
  [string]$UpgradeCode = $(if ($env:UPGRADE_CODE) { $env:UPGRADE_CODE } else { "6F4DF7EA-B747-4C6D-9E18-4998A51647B0" })
)

$ErrorActionPreference = "Stop"

$AppId = "monomertodo"
$AppName = "MonomerTodo"
$ExeName = "app"
$RootDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$DistDir = Join-Path $RootDir "dist"
$BuildDir = Join-Path $RootDir "build\release"
$StageDir = Join-Path $BuildDir "windows"
$PackageDir = Join-Path $StageDir "package"
$WxsPath = Join-Path $StageDir "$AppName.wxs"
$MsiPath = Join-Path $DistDir "$AppName-$Version-x64.msi"

function Require-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Get-StackBinary {
  $InstallRoot = (& stack path --local-install-root).Trim()
  $Binary = Join-Path $InstallRoot "bin\$ExeName.exe"
  if (-not (Test-Path $Binary)) {
    throw "Built executable not found: $Binary"
  }
  return $Binary
}

function Copy-Directory {
  param(
    [string]$Source,
    [string]$Destination
  )
  if (Test-Path $Destination) {
    Remove-Item -Recurse -Force $Destination
  }
  New-Item -ItemType Directory -Force -Path $Destination | Out-Null
  Copy-Item -Recurse -Force (Join-Path $Source "*") $Destination
}

function New-ShortcutComponent {
  @"
      <Component Id="StartMenuShortcutComponent" Guid="*">
        <Shortcut Id="StartMenuShortcut"
                  Directory="ApplicationProgramsFolder"
                  Name="$AppName"
                  WorkingDirectory="INSTALLFOLDER"
                  Target="[INSTALLFOLDER]$AppName.exe" />
        <RemoveFolder Id="ApplicationProgramsFolder" On="uninstall" />
        <RegistryValue Root="HKCU" Key="Software\$Manufacturer\$AppName" Name="installed" Type="integer" Value="1" KeyPath="yes" />
      </Component>
"@
}

function New-WixV3Source {
  param([string]$OutputPath)

  $AssetsDir = Join-Path $PackageDir "assets"
  $FontFiles = Get-ChildItem -Path (Join-Path $AssetsDir "fonts") -File | Sort-Object Name
  $ImageFiles = Get-ChildItem -Path (Join-Path $AssetsDir "images") -File | Sort-Object Name
  $ShortcutComponent = New-ShortcutComponent

  $FontComponents = foreach ($File in $FontFiles) {
    $Id = "Font_" + ($File.BaseName -replace '[^A-Za-z0-9_]', '_')
    @"
        <Component Id="$Id" Guid="*">
          <File Source="$($File.FullName)" KeyPath="yes" />
        </Component>
"@
  }

  $ImageComponents = foreach ($File in $ImageFiles) {
    $Id = "Image_" + ($File.BaseName -replace '[^A-Za-z0-9_]', '_')
    @"
        <Component Id="$Id" Guid="*">
          <File Source="$($File.FullName)" KeyPath="yes" />
        </Component>
"@
  }

  $FontRefs = foreach ($File in $FontFiles) {
    $Id = "Font_" + ($File.BaseName -replace '[^A-Za-z0-9_]', '_')
    "      <ComponentRef Id=""$Id"" />"
  }

  $ImageRefs = foreach ($File in $ImageFiles) {
    $Id = "Image_" + ($File.BaseName -replace '[^A-Za-z0-9_]', '_')
    "      <ComponentRef Id=""$Id"" />"
  }

  $ExePath = Join-Path $PackageDir "$AppName.exe"
  @"
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Product Id="*" Name="$AppName" Language="1033" Version="$Version" Manufacturer="$Manufacturer" UpgradeCode="$UpgradeCode">
    <Package InstallerVersion="500" Compressed="yes" InstallScope="perMachine" Platform="x64" />
    <MajorUpgrade DowngradeErrorMessage="A newer version of $AppName is already installed." />
    <MediaTemplate EmbedCab="yes" />

    <Directory Id="TARGETDIR" Name="SourceDir">
      <Directory Id="ProgramFiles64Folder">
        <Directory Id="INSTALLFOLDER" Name="$AppName">
          <Component Id="MainExecutable" Guid="*">
            <File Id="AppExecutable" Source="$ExePath" KeyPath="yes" />
          </Component>
          <Directory Id="AssetsFolder" Name="assets">
            <Directory Id="FontsFolder" Name="fonts">
$($FontComponents -join "`r`n")
            </Directory>
            <Directory Id="ImagesFolder" Name="images">
$($ImageComponents -join "`r`n")
            </Directory>
          </Directory>
        </Directory>
      </Directory>
      <Directory Id="ProgramMenuFolder">
        <Directory Id="ApplicationProgramsFolder" Name="$AppName">
$ShortcutComponent
        </Directory>
      </Directory>
    </Directory>

    <Feature Id="MainFeature" Title="$AppName" Level="1">
      <ComponentRef Id="MainExecutable" />
      <ComponentRef Id="StartMenuShortcutComponent" />
$($FontRefs -join "`r`n")
$($ImageRefs -join "`r`n")
    </Feature>
  </Product>
</Wix>
"@ | Set-Content -Encoding UTF8 -Path $OutputPath
}

function New-WixV4Source {
  param([string]$OutputPath)

  $AssetsDir = Join-Path $PackageDir "assets"
  $FontFiles = Get-ChildItem -Path (Join-Path $AssetsDir "fonts") -File | Sort-Object Name
  $ImageFiles = Get-ChildItem -Path (Join-Path $AssetsDir "images") -File | Sort-Object Name
  $ShortcutComponent = New-ShortcutComponent

  $FontComponents = foreach ($File in $FontFiles) {
    $Id = "Font_" + ($File.BaseName -replace '[^A-Za-z0-9_]', '_')
    @"
        <Component Id="$Id" Guid="*">
          <File Source="$($File.FullName)" KeyPath="yes" />
        </Component>
"@
  }

  $ImageComponents = foreach ($File in $ImageFiles) {
    $Id = "Image_" + ($File.BaseName -replace '[^A-Za-z0-9_]', '_')
    @"
        <Component Id="$Id" Guid="*">
          <File Source="$($File.FullName)" KeyPath="yes" />
        </Component>
"@
  }

  $FontRefs = foreach ($File in $FontFiles) {
    $Id = "Font_" + ($File.BaseName -replace '[^A-Za-z0-9_]', '_')
    "      <ComponentRef Id=""$Id"" />"
  }

  $ImageRefs = foreach ($File in $ImageFiles) {
    $Id = "Image_" + ($File.BaseName -replace '[^A-Za-z0-9_]', '_')
    "      <ComponentRef Id=""$Id"" />"
  }

  $ExePath = Join-Path $PackageDir "$AppName.exe"

  @"
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs">
  <Package Name="$AppName" Manufacturer="$Manufacturer" Version="$Version" UpgradeCode="$UpgradeCode" Scope="perMachine">
    <MajorUpgrade DowngradeErrorMessage="A newer version of $AppName is already installed." />
    <MediaTemplate EmbedCab="yes" />

    <StandardDirectory Id="ProgramFiles64Folder">
      <Directory Id="INSTALLFOLDER" Name="$AppName">
        <Component Id="MainExecutable" Guid="*">
          <File Id="AppExecutable" Source="$ExePath" KeyPath="yes" />
        </Component>
        <Directory Id="AssetsFolder" Name="assets">
          <Directory Id="FontsFolder" Name="fonts">
$($FontComponents -join "`r`n")
          </Directory>
          <Directory Id="ImagesFolder" Name="images">
$($ImageComponents -join "`r`n")
          </Directory>
        </Directory>
      </Directory>
    </StandardDirectory>

    <StandardDirectory Id="ProgramMenuFolder">
      <Directory Id="ApplicationProgramsFolder" Name="$AppName">
$ShortcutComponent
      </Directory>
    </StandardDirectory>

    <Feature Id="MainFeature" Title="$AppName" Level="1">
      <ComponentRef Id="MainExecutable" />
      <ComponentRef Id="StartMenuShortcutComponent" />
$($FontRefs -join "`r`n")
$($ImageRefs -join "`r`n")
    </Feature>
  </Package>
</Wix>
"@ | Set-Content -Encoding UTF8 -Path $OutputPath
}

function Build-WithWixV3 {
  Require-Command "candle.exe"
  Require-Command "light.exe"

  $WixObj = Join-Path $StageDir "$AppName.wixobj"
  & candle.exe -arch x64 -out $WixObj $WxsPath
  & light.exe -out $MsiPath $WixObj
}

function Build-WithWixV4 {
  Require-Command "wix.exe"
  & wix.exe build -arch x64 -out $MsiPath $WxsPath
}

Require-Command "stack"

Write-Host "Building $AppName with Stack..."
Push-Location $RootDir
try {
  & stack build
}
finally {
  Pop-Location
}

if (Test-Path $BuildDir) {
  Remove-Item -Recurse -Force $BuildDir
}
New-Item -ItemType Directory -Force -Path $DistDir, $PackageDir | Out-Null

$Binary = Get-StackBinary
Copy-Item -Force $Binary (Join-Path $PackageDir "$AppName.exe")
Copy-Directory -Source (Join-Path $RootDir "assets") -Destination (Join-Path $PackageDir "assets")

if (Get-Command "wix.exe" -ErrorAction SilentlyContinue) {
  New-WixV4Source -OutputPath $WxsPath
  Build-WithWixV4
}
elseif (Get-Command "candle.exe" -ErrorAction SilentlyContinue) {
  New-WixV3Source -OutputPath $WxsPath
  Build-WithWixV3
}
else {
  throw "WiX Toolset is required. Install WiX v4 (wix.exe) or WiX v3 (candle.exe/light.exe)."
}

Write-Host "Windows release artifact written to $MsiPath"
