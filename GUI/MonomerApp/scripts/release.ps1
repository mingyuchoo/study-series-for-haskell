[CmdletBinding()]
param(
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..")
$PackageYaml = Join-Path $ProjectRoot "package.yaml"

$AppName = if ($env:APP_NAME) { $env:APP_NAME } else { "MonomerApp" }
$PackageName = if ($env:PACKAGE_NAME) { $env:PACKAGE_NAME } else { "monomerapp" }
$ExecutableName = if ($env:EXECUTABLE_NAME) { $env:EXECUTABLE_NAME } else { "app" }
$StackBin = if ($env:STACK) { $env:STACK } else { "stack" }
$MakeBin = if ($env:MAKE) { $env:MAKE } else { "make" }
$Manufacturer = if ($env:MANUFACTURER) { $env:MANUFACTURER } else { "example.com" }
$UpgradeCode = if ($env:UPGRADE_CODE) { $env:UPGRADE_CODE } else { "4E35D51C-F4BA-4D64-9C49-50C24307CF81" }
$StartMenuShortcutGuid = if ($env:START_MENU_SHORTCUT_GUID) { $env:START_MENU_SHORTCUT_GUID } else { "9D54C789-3A6C-44A8-A7C3-2ED446107AB1" }

$Version = if ($env:VERSION) {
  $env:VERSION
} else {
  $line = Get-Content $PackageYaml | Where-Object { $_ -match "^version:\s+" } | Select-Object -First 1
  if (-not $line) {
    throw "Could not read version from $PackageYaml"
  }
  ($line -replace "^version:\s+", "").Trim()
}

$MsiVersionParts = $Version.Split(".") | Select-Object -First 3
while ($MsiVersionParts.Count -lt 3) {
  $MsiVersionParts += "0"
}
$MsiVersion = ($MsiVersionParts -join ".")

$DistDir = Join-Path $ProjectRoot "dist\release"
$WorkDir = Join-Path $DistDir "work"
$PayloadDir = Join-Path $WorkDir "payload"
$BinDir = Join-Path $PayloadDir "bin"
$MsiRoot = Join-Path $WorkDir "msi-root"

function Show-Usage {
  @"
Usage: scripts\release.ps1

Builds and tests the app through the Makefile, then creates:
  dist\release\$AppName-$Version.msi

Required platform tools:
  stack, make, and WiX Toolset v3 candle/light or WiX v4 wix.exe
"@
}

function Require-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Invoke-Make([string]$Target) {
  Write-Host ""
  Write-Host "==> make $Target"
  & $MakeBin -C $ProjectRoot $Target
  if ($LASTEXITCODE -ne 0) {
    throw "make $Target failed with exit code $LASTEXITCODE"
  }
}

function ConvertTo-WixId([string]$Prefix, [string]$Value) {
  $clean = ($Value -replace "[^A-Za-z0-9_]", "_")
  if ($clean.Length -gt 60) {
    $hash = [Math]::Abs($clean.GetHashCode())
    $clean = $clean.Substring(0, 45) + "_" + $hash
  }
  return "${Prefix}_${clean}"
}

function Escape-Xml([string]$Value) {
  return [System.Security.SecurityElement]::Escape($Value)
}

function New-WixDirectoryXml {
  param(
    [string]$DirectoryPath,
    [string]$BasePath,
    [string]$Indent,
    [System.Collections.Generic.List[string]]$ComponentRefs
  )

  $xml = New-Object System.Collections.Generic.List[string]

  Get-ChildItem -LiteralPath $DirectoryPath -File | Sort-Object Name | ForEach-Object {
    $relative = [System.IO.Path]::GetRelativePath($BasePath, $_.FullName)
    $componentId = ConvertTo-WixId "cmp" $relative
    $fileId = ConvertTo-WixId "fil" $relative
    $guid = [Guid]::NewGuid().ToString().ToUpperInvariant()
    $source = Escape-Xml $_.FullName

    $xml.Add("$Indent<Component Id=`"$componentId`" Guid=`"$guid`">")
    $xml.Add("$Indent  <File Id=`"$fileId`" Source=`"$source`" KeyPath=`"yes`" />")
    $xml.Add("$Indent</Component>")
    $ComponentRefs.Add("      <ComponentRef Id=`"$componentId`" />")
  }

  Get-ChildItem -LiteralPath $DirectoryPath -Directory | Sort-Object Name | ForEach-Object {
    $relative = [System.IO.Path]::GetRelativePath($BasePath, $_.FullName)
    $directoryId = ConvertTo-WixId "dir" $relative
    $name = Escape-Xml $_.Name

    $xml.Add("$Indent<Directory Id=`"$directoryId`" Name=`"$name`">")
    $childXml = New-WixDirectoryXml -DirectoryPath $_.FullName -BasePath $BasePath -Indent "$Indent  " -ComponentRefs $ComponentRefs
    $childXml | ForEach-Object { $xml.Add($_) }
    $xml.Add("$Indent</Directory>")
  }

  return $xml
}

function Prepare-Binary {
  if (Test-Path $WorkDir) {
    Remove-Item -Recurse -Force $WorkDir
  }
  New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

  Write-Host ""
  Write-Host "==> stack install ${AppName}:exe:${ExecutableName}"
  & $StackBin install "${AppName}:exe:${ExecutableName}" --local-bin-path $BinDir
  if ($LASTEXITCODE -ne 0) {
    throw "stack install failed with exit code $LASTEXITCODE"
  }

  $exePath = Join-Path $BinDir "$ExecutableName.exe"
  if (-not (Test-Path $exePath)) {
    throw "Expected executable was not created: $exePath"
  }
}

function Prepare-MsiRoot {
  if (Test-Path $MsiRoot) {
    Remove-Item -Recurse -Force $MsiRoot
  }
  New-Item -ItemType Directory -Force -Path $MsiRoot | Out-Null

  Copy-Item (Join-Path $BinDir "$ExecutableName.exe") (Join-Path $MsiRoot "$ExecutableName.exe")
  Copy-Item -Recurse (Join-Path $ProjectRoot "assets") (Join-Path $MsiRoot "assets")
}

function Build-Msi {
  Require-Command $StackBin
  Require-Command $MakeBin

  New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
  Prepare-MsiRoot

  $componentRefs = New-Object System.Collections.Generic.List[string]
  $directoryXml = New-WixDirectoryXml -DirectoryPath $MsiRoot -BasePath $MsiRoot -Indent "          " -ComponentRefs $componentRefs
  $componentRefsXml = $componentRefs -join [Environment]::NewLine

  $wxsPath = Join-Path $WorkDir "$PackageName.wxs"
  $msiPath = Join-Path $DistDir "$AppName-$Version.msi"
  $appNameXml = Escape-Xml $AppName
  $manufacturerXml = Escape-Xml $Manufacturer

  $wxs = @"
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Product Id="*" Name="$appNameXml" Language="1033" Version="$MsiVersion" Manufacturer="$manufacturerXml" UpgradeCode="$UpgradeCode">
    <Package InstallerVersion="500" Compressed="yes" InstallScope="perMachine" />
    <MajorUpgrade DowngradeErrorMessage="A newer version of $appNameXml is already installed." />
    <MediaTemplate EmbedCab="yes" />

    <Directory Id="TARGETDIR" Name="SourceDir">
      <Directory Id="ProgramFilesFolder">
        <Directory Id="INSTALLFOLDER" Name="$appNameXml">
$($directoryXml -join [Environment]::NewLine)
        </Directory>
      </Directory>
      <Directory Id="ProgramMenuFolder">
        <Directory Id="ApplicationProgramsFolder" Name="$appNameXml" />
      </Directory>
    </Directory>

    <DirectoryRef Id="ApplicationProgramsFolder">
      <Component Id="cmp_StartMenuShortcut" Guid="$StartMenuShortcutGuid">
        <Shortcut Id="ApplicationStartMenuShortcut"
                  Name="$appNameXml"
                  Description="$appNameXml"
                  Target="[INSTALLFOLDER]$ExecutableName.exe"
                  WorkingDirectory="INSTALLFOLDER" />
        <RemoveFolder Id="ApplicationProgramsFolder" On="uninstall" />
        <RegistryValue Root="HKCU"
                       Key="Software\$appNameXml"
                       Name="installed"
                       Type="integer"
                       Value="1"
                       KeyPath="yes" />
      </Component>
    </DirectoryRef>

    <Feature Id="ProductFeature" Title="$appNameXml" Level="1">
      <ComponentGroupRef Id="AppComponents" />
    </Feature>

    <ComponentGroup Id="AppComponents" Directory="INSTALLFOLDER">
      <ComponentRef Id="cmp_StartMenuShortcut" />
$componentRefsXml
    </ComponentGroup>
  </Product>
</Wix>
"@
  Set-Content -Path $wxsPath -Value $wxs -Encoding UTF8

  $wix = Get-Command "wix.exe" -ErrorAction SilentlyContinue
  if ($wix) {
    Write-Host ""
    Write-Host "==> wix build"
    & $wix.Source build $wxsPath -o $msiPath
    if ($LASTEXITCODE -ne 0) {
      throw "wix build failed with exit code $LASTEXITCODE"
    }
  } else {
    Require-Command "candle.exe"
    Require-Command "light.exe"
    $wixObj = Join-Path $WorkDir "$PackageName.wixobj"

    Write-Host ""
    Write-Host "==> candle/light"
    & candle.exe -out $wixObj $wxsPath
    if ($LASTEXITCODE -ne 0) {
      throw "candle.exe failed with exit code $LASTEXITCODE"
    }
    & light.exe -out $msiPath $wixObj
    if ($LASTEXITCODE -ne 0) {
      throw "light.exe failed with exit code $LASTEXITCODE"
    }
  }

  Write-Host "Created $msiPath"
}

if ($Help) {
  Show-Usage
  exit 0
}

Invoke-Make "build"
Invoke-Make "test"
Prepare-Binary
Build-Msi
