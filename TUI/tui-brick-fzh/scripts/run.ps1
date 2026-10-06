[CmdletBinding()]
param(
    [ValidateSet("build", "test", "run", "all", "clean", "help")]
    [string]$Command = "run"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Resolve-Path (Join-Path $ScriptDir "..")

function Format-HaskellFile {
    param([System.IO.FileInfo]$File)

    Write-Host "Processing $($File.FullName)"

    try {
        & stylish-haskell -i $File.FullName
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to format $($File.FullName)"
        }
    }
    catch {
        Write-Host "Failed to format $($File.FullName)"
    }
}

function Format-HaskellDirectory {
    param(
        [string]$Path,
        [string]$Name
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        Write-Host "Directory $Name does not exist, skipping..."
        return
    }

    $files = @(Get-ChildItem -LiteralPath $Path -Recurse -File -Filter "*.hs" -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) {
        Write-Host "No Haskell files found in $Name, skipping..."
        return
    }

    foreach ($file in $files) {
        if ($Name -eq "test" -and (Select-String -LiteralPath $file.FullName -SimpleMatch "<|" -Quiet)) {
            Write-Host "Processing $($file.FullName)"
            Write-Host "Skipping $($file.FullName) (contains <| operator)"
        }
        else {
            Format-HaskellFile $file
        }
    }
}

function Format-HaskellFiles {
    Write-Host "Formatting Haskell files..."

    Format-HaskellDirectory (Join-Path $RootDir "src") "src"
    Format-HaskellDirectory (Join-Path $RootDir "app") "app"
    Format-HaskellDirectory (Join-Path $RootDir "test") "test"

    $rootFiles = @(Get-ChildItem -LiteralPath $RootDir -File -Filter "*.hs" -ErrorAction SilentlyContinue)
    foreach ($file in $rootFiles) {
        Format-HaskellFile $file
    }

    Write-Host "Formatting complete"
}

Format-HaskellFiles

function Show-Usage {
    @"
Usage: ./scripts/run.ps1 <command>

Commands:
  build   Build the project with Makefile
  test    Run tests with Makefile
  run     Build and run the app with Makefile
  all     Clean, setup, build, test, and run with Makefile
  clean   Clean build artifacts with Makefile
"@
}

if ($Command -eq "help") {
    Show-Usage
    exit 0
}

Push-Location $RootDir
try {
    & make $Command
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}
