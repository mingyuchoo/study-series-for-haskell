[CmdletBinding()]
param(
    [string]$OutputDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'dist/release'),
    [string]$InnoSetupCompiler = 'ISCC.exe'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($env:OS -ne 'Windows_NT') {
    throw 'Run release.ps1 on Windows 11. Use release.sh on Linux or macOS.'
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$OutputDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDir)

foreach ($tool in @('stack', 'fourmolu', 'hlint', $InnoSetupCompiler)) {
    if (-not (Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue)) {
        throw "Required tool not found: $tool. See README.md for release prerequisites."
    }
}

function Invoke-Native {
    param(
        [string]$Command,
        [string[]]$CommandArguments,
        [string]$Label = $Command
    )

    Write-Host "`n==> $Label"
    & $Command @CommandArguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

function Copy-RuntimeLibraries {
    param([string]$Executable, [string]$BinDirectory)

    $pending = [System.Collections.Generic.Queue[string]]::new()
    $visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $pending.Enqueue($Executable)
    while ($pending.Count -gt 0) {
        $current = $pending.Dequeue()
        $imports = @(Invoke-Native -Command 'stack' -CommandArguments @('exec', '--', 'objdump', '-p', $current) -Label "Inspecting $current")
        foreach ($line in $imports) {
            if ($line -notmatch '^\s*DLL Name:\s*(\S+)\s*$') {
                continue
            }
            $libraryName = $Matches[1]
            if (-not $visited.Add($libraryName)) {
                continue
            }
            $systemLibrary = Join-Path (Join-Path $env:WINDIR 'System32') $libraryName
            if ($libraryName -match '^(api-ms-win-|ext-ms-win-)' -or (Test-Path -LiteralPath $systemLibrary -PathType Leaf)) {
                continue
            }
            $libraryPath = Join-Path (Split-Path -Parent $current) $libraryName
            if (-not (Test-Path -LiteralPath $libraryPath -PathType Leaf)) {
                $candidates = @(Invoke-Native -Command 'stack' -CommandArguments @('exec', '--', 'where.exe', $libraryName) -Label "Locating $libraryName")
                $libraryPath = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
            }
            if (-not $libraryPath) {
                throw "Cannot locate runtime library: $libraryName"
            }
            $destination = Join-Path $BinDirectory $libraryName
            Copy-Item -LiteralPath $libraryPath -Destination $destination
            $pending.Enqueue($destination)
        }
    }
}

$workDirectory = $null
$publicationDirectory = $null
Push-Location -LiteralPath $projectRoot
try {
    $versionLine = Select-String -LiteralPath 'package.yaml' -Pattern '^version:\s*(\d+(?:\.\d+)*)\s*$'
    if (-not $versionLine -or @($versionLine).Count -ne 1) {
        throw 'package.yaml must contain one numeric version.'
    }
    $version = $versionLine.Matches[0].Groups[1].Value
    $sourceFiles = @(
        Get-ChildItem -LiteralPath 'apps', 'packages', 'test' -Recurse -File -Filter '*.hs' |
            Where-Object { $_.FullName -notmatch '[\\/]\.stack-work[\\/]' } |
            Sort-Object FullName |
            ForEach-Object { $_.FullName }
        (Get-Item -LiteralPath 'Setup.hs').FullName
    )

    Invoke-Native -Label 'Formatting' -Command 'fourmolu' -CommandArguments (@('--mode', 'inplace') + $sourceFiles)
    Invoke-Native -Label 'Linting' -Command 'hlint' -CommandArguments @('apps', 'packages', 'test', 'Setup.hs')
    Invoke-Native -Label 'Building' -Command 'stack' -CommandArguments @('build', '--test', '--no-run-tests', '--ghc-options=-O2')
    Invoke-Native -Label 'Testing' -Command 'stack' -CommandArguments @('test', '--ghc-options=-O2')

    $target = (Invoke-Native -Command 'stack' -CommandArguments @('exec', '--', 'ghc', '--print-target-platform') -Label 'Detecting compiler target' | Out-String).Trim()
    switch -Regex ($target) {
        '^x86_64-.*mingw32$' { $architecture = 'x86_64'; $installerArchitecture = 'x64compatible'; break }
        '^aarch64-.*mingw32$' { $architecture = 'arm64'; $installerArchitecture = 'arm64'; break }
        default { throw "Unsupported Windows compiler target: $target" }
    }
    $installRoot = (Invoke-Native -Command 'stack' -CommandArguments @('path', '--local-install-root') -Label 'Locating executable' | Out-String).Trim()
    $binary = Join-Path $installRoot 'bin/tto-exe.exe'
    if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) {
        throw "Built executable not found: $binary"
    }

    $workDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('tto-release-' + [System.Guid]::NewGuid().ToString('N'))
    $artifactName = "tto-$version-windows-$architecture"
    $bundle = Join-Path $workDirectory $artifactName
    $artifacts = Join-Path $workDirectory 'artifacts'
    $binDirectory = Join-Path $bundle 'bin'
    $configDirectory = Join-Path $bundle 'share/tto/config'
    $documentationDirectory = Join-Path $bundle 'share/doc/tto'
    New-Item -ItemType Directory -Path $binDirectory, $configDirectory, $documentationDirectory, $artifacts | Out-Null
    Copy-Item -LiteralPath $binary -Destination (Join-Path $binDirectory 'tto.exe')
    Get-ChildItem -LiteralPath 'config' -File -Filter '*.yaml' |
        Copy-Item -Destination $configDirectory
    Copy-Item -LiteralPath 'LICENSE', 'README.md', 'CHANGELOG.md' -Destination $documentationDirectory
    @'
Run bin\tto.exe in Windows Terminal with a UTF-8 locale.
Keep the bundle directories together when using the ZIP archive.
Configuration examples are in share\tto\config.
Copy selected YAML files to %USERPROFILE%\.config\tto to customize the application.
User configuration and todos.db are stored in %USERPROFILE%\.config\tto.
'@ | Set-Content -LiteralPath (Join-Path $documentationDirectory 'INSTALL.txt') -Encoding UTF8

    Copy-RuntimeLibraries -Executable (Join-Path $binDirectory 'tto.exe') -BinDirectory $binDirectory
    Compress-Archive -LiteralPath $bundle -DestinationPath (Join-Path $artifacts "$artifactName.zip") -CompressionLevel Optimal
    Invoke-Native -Label 'Creating Windows installer' -Command $InnoSetupCompiler -CommandArguments @(
        "/DBundleDir=$bundle",
        "/DReleaseVersion=$version",
        "/DReleaseArchitecture=$installerArchitecture",
        "/O$artifacts",
        "/F$artifactName-setup",
        (Join-Path $PSScriptRoot 'packaging/windows.iss')
    )
    if (-not (Test-Path -LiteralPath (Join-Path $artifacts "$artifactName-setup.exe") -PathType Leaf)) {
        throw 'Inno Setup did not produce the expected installer.'
    }

    $checksums = @(Get-ChildItem -LiteralPath $artifacts -File | Sort-Object Name | ForEach-Object {
        $digest = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$digest  $($_.Name)"
    })
    [System.IO.File]::WriteAllLines((Join-Path $artifacts 'SHA256SUMS'), $checksums, [System.Text.UTF8Encoding]::new($false))
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    $releaseDirectory = Join-Path $OutputDir $artifactName
    if (Test-Path -LiteralPath $releaseDirectory) {
        throw "Release already exists: $releaseDirectory. Choose another -OutputDir."
    }
    $publicationDirectory = Join-Path $OutputDir ('.tto-release-' + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $publicationDirectory | Out-Null
    Get-ChildItem -LiteralPath $artifacts -File | Copy-Item -Destination $publicationDirectory
    [System.IO.Directory]::Move($publicationDirectory, $releaseDirectory)
    $publicationDirectory = $null
    Write-Host "`nRelease artifacts: $releaseDirectory"
}
finally {
    Pop-Location
    if ($publicationDirectory -and (Test-Path -LiteralPath $publicationDirectory)) {
        Remove-Item -LiteralPath $publicationDirectory -Recurse -Force
    }
    if ($workDirectory -and (Test-Path -LiteralPath $workDirectory)) {
        Remove-Item -LiteralPath $workDirectory -Recurse -Force
    }
}
