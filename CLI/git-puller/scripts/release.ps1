param(
    [string]$OutputDirectory = (Join-Path (Split-Path $PSScriptRoot) 'dist'),

    [string]$InnoCompiler = 'ISCC.exe'
)

$ErrorActionPreference = 'Stop'

function Invoke-ReleaseCommand {
    param([string]$Command, [string[]]$Arguments)
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command failed with exit code $LASTEXITCODE."
    }
}

if ($env:OS -ne 'Windows_NT') {
    throw 'This release script requires Windows 11 with WSL and Inno Setup.'
}

$project = Join-Path (Split-Path $PSScriptRoot) 'apps/git-puller/git-puller.cabal'
$versionFields = @(Select-String -LiteralPath $project -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$')
if ($versionFields.Count -ne 1) {
    throw "Expected exactly one version: MAJOR.MINOR.PATCH field in $project."
}
$Version = $versionFields[0].Matches[0].Groups[1].Value

$null = Get-Command wsl.exe, tar.exe, $InnoCompiler -CommandType Application
$architecture = Invoke-ReleaseCommand wsl.exe @('--exec', 'uname', '-m')
$windowsArchitecture = switch ($architecture) {
    'x86_64' { 'x64os' }
    'aarch64' { 'arm64' }
    default { throw "Unsupported WSL architecture $architecture." }
}

$packaging = Join-Path $PSScriptRoot 'packaging'
$launcher = Join-Path $packaging 'git-puller.ps1'
$tokens = $null
$parseErrors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($launcher, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) {
    throw ($parseErrors -join [Environment]::NewLine)
}

$output = (New-Item -Path $OutputDirectory -ItemType Directory -Force).FullName
$staging = Join-Path ([IO.Path]::GetTempPath()) ("git-puller-" + [guid]::NewGuid())
$null = New-Item -Path $staging -ItemType Directory

try {
    $releaseRunner = Join-Path $PSScriptRoot 'release.sh'
    $wslRunner = Invoke-ReleaseCommand wsl.exe @('--exec', 'wslpath', '-u', $releaseRunner)
    $wslStaging = Invoke-ReleaseCommand wsl.exe @('--exec', 'wslpath', '-u', $staging)
    Invoke-ReleaseCommand wsl.exe @('--exec', 'bash', $wslRunner, '--bundle-only', $wslStaging)

    $linuxName = "git-puller-$Version-linux-$architecture"
    $windowsName = "git-puller-$Version-windows-wsl-$architecture"
    Invoke-ReleaseCommand tar.exe @('-xzf', (Join-Path $staging "$linuxName.tar.gz"), '-C', $staging)
    $bundle = Join-Path $staging 'bundle'
    Move-Item -LiteralPath (Join-Path $staging $linuxName) -Destination $bundle
    Copy-Item -LiteralPath $launcher -Destination $bundle

    Write-Host "`n==> Package"
    $definition = Join-Path $staging 'windows.iss'
    Copy-Item -LiteralPath (Join-Path $packaging 'windows.iss') -Destination $definition
    @'
Git Puller requires a WSL distribution with Git installed.
Use a WSL distribution with the same architecture and a compatible glibc.
Run git-puller.ps1 from the installation directory and pass WSL-style project paths.
'@ | Set-Content -LiteralPath (Join-Path $staging 'requirements.txt') -Encoding Ascii
    Invoke-ReleaseCommand $InnoCompiler @(
        "/DReleaseVersion=$Version",
        "/DReleaseArch=$architecture",
        "/DWindowsArch=$windowsArchitecture",
        "/O$staging",
        $definition
    )
    $zip = Join-Path $staging "$windowsName.zip"
    Compress-Archive -Path (Join-Path $bundle '*') -DestinationPath $zip
    Move-Item -LiteralPath $zip, (Join-Path $staging "$windowsName-setup.exe") -Destination $output -Force
    Write-Host "`nArtifacts written to $output"
} finally {
    Remove-Item -LiteralPath $staging -Recurse -Force
}
