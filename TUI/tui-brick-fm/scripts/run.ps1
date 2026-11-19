[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("format", "lint", "build", "test", "run", "all", "clean", "help")]
    [string]$Command = "all",

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Directories = @()
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$RootDir = Split-Path -Parent $PSScriptRoot

if ($Command -eq "help") {
    Write-Host "Usage: scripts/run.ps1 [format|lint|build|test|run|all|clean|help] [LEFT_DIR] [RIGHT_DIR]"
    Write-Host "  format Format workspace Haskell sources with stylish-haskell"
    Write-Host "  lint   Check workspace Haskell sources with HLint"
    Write-Host "  build  Build hfm"
    Write-Host "  test   Check architecture and run the test suite"
    Write-Host "  run    Build and open the file manager"
    Write-Host "  all    Format, lint, build, test, then open the file manager (default)"
    Write-Host "  clean  Remove Stack build artifacts"
    Write-Host "Directory arguments are accepted by run and all. Run in an interactive terminal."
    Write-Host "Required tools: stylish-haskell (format), hlint (lint), Stack (build/test/run/clean)."
    Write-Host "The all command requires every tool. PowerShell runs natively without Bash or WSL."
    exit 0
}

if ($Command -notin @("run", "all") -and $Directories.Count -gt 0) {
    throw "Directory arguments are only accepted by run and all"
}
if ($Directories.Count -gt 2) {
    throw "At most two starting directories are supported"
}

$StartingDirectories = @(
    foreach ($directory in $Directories) {
        $item = Get-Item -LiteralPath $directory
        if (-not $item.PSIsContainer -or $item.PSProvider.Name -ne 'FileSystem') {
            throw "Not a filesystem directory: $directory"
        }
        $item.FullName
    }
)

$RequiredTools = switch ($Command) {
    'format' { 'stylish-haskell' }
    'lint' { 'hlint' }
    'test' { 'stack' }
    'all' { 'stylish-haskell'; 'hlint'; 'stack' }
    default { 'stack' }
}
foreach ($tool in $RequiredTools) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool is required. Install it and add it to PATH."
    }
}

function Invoke-Checked($Tool, [string[]]$Arguments) {
    & $Tool @Arguments
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Push-Location -LiteralPath $RootDir
try {
    if ($Command -in @('format', 'lint', 'all')) {
        $SourceDirectories = @(
            foreach ($workspace in 'apps', 'packages') {
                foreach ($package in Get-ChildItem -LiteralPath $workspace -Directory) {
                    foreach ($name in 'app', 'src', 'test', 'pty') {
                        $path = Join-Path $package.FullName $name
                        if (Test-Path -LiteralPath $path -PathType Container) { $path }
                    }
                }
            }
        )
        if ($SourceDirectories.Count -eq 0) { throw 'No workspace source directories found' }
        $SourceFiles = @(
            Get-ChildItem -LiteralPath $SourceDirectories -Recurse -File -Filter '*.hs' |
                Sort-Object FullName |
                ForEach-Object { $_.FullName.Substring($RootDir.Length + 1).Replace('\', '/') }
        )
        if ($SourceFiles.Count -eq 0) { throw 'No workspace Haskell sources found' }
    }
    if ($Command -in @('format', 'all')) {
        Invoke-Checked stylish-haskell (@('--config', '.stylish-haskell.yaml', '-i') + $SourceFiles)
    }
    if ($Command -in @('lint', 'all')) { Invoke-Checked hlint $SourceFiles }
    if ($Command -in @('build', 'all')) { Invoke-Checked stack @('build') }
    if ($Command -in @('test', 'all')) {
        Invoke-Checked stack @('run', 'hfm-check-architecture')
        Invoke-Checked stack @('test')
    }
    if ($Command -in @('run', 'all')) {
        Invoke-Checked stack (@('run', 'hfm', '--') + $StartingDirectories)
    }
    if ($Command -eq 'clean') { Invoke-Checked stack @('clean') }
}
finally {
    Pop-Location
}
exit 0
