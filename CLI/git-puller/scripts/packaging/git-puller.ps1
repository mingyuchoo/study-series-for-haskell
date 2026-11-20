$ErrorActionPreference = 'Stop'

$runner = Join-Path $PSScriptRoot 'bin\git-puller'
$wslRunner = & wsl.exe --exec wslpath -u $runner
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

& wsl.exe --exec test -x $wslRunner
if ($LASTEXITCODE -ne 0) {
    & wsl.exe --exec chmod u+x -- $wslRunner
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

& wsl.exe --exec $wslRunner @args
exit $LASTEXITCODE
