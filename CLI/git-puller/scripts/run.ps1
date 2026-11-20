$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'run.sh'

if ($env:OS -eq 'Windows_NT') {
    $wslRunner = & wsl.exe --exec wslpath -u $runner
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    & wsl.exe --exec bash $wslRunner @args
} else {
    & bash $runner @args
}

exit $LASTEXITCODE
