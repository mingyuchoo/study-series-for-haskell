$ErrorActionPreference = 'Stop'
$PowerShell = (Get-Process -Id $PID).Path
$Fixture = Join-Path ([IO.Path]::GetTempPath()) ("hfm scripts " + [char]0xD55C + [char]0xAE00 + ' ' + [guid]::NewGuid())

function Assert($Condition, $Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-Fixture($Script, $Command, [string[]]$Directories = @(), $Fail = '') {
    $env:HFM_TEST_LOG = Join-Path $Fixture 'calls.jsonl'
    $env:HFM_TEST_FAIL = $Fail
    Set-Content -LiteralPath $env:HFM_TEST_LOG -Value ''
    # Windows PowerShell turns redirected native stderr into ErrorRecords.
    $ErrorActionPreference = 'Continue'
    $output = & $PowerShell -NoProfile -File (Join-Path $Fixture 'runner.ps1') $Script $Command @Directories 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $calls = @(Get-Content -LiteralPath $env:HFM_TEST_LOG | Where-Object { $_ } | ForEach-Object { ConvertFrom-Json $_ })
    return @{ Code = $code; Calls = $calls; Output = ($output -join "`n") }
}

try {
    New-Item -ItemType Directory -Path (Join-Path $Fixture 'scripts'), (Join-Path $Fixture 'apps/hfm') | Out-Null
    foreach ($name in 'run.ps1', 'release.ps1', 'windows-installer.nsi') {
        $source = Join-Path $PSScriptRoot $name
        if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination (Join-Path $Fixture 'scripts') }
    }
    Set-Content -LiteralPath (Join-Path $Fixture 'apps/hfm/package.yaml') -Value "name: hfm`nversion: 0.1.0.0"
    Set-Content -LiteralPath (Join-Path $Fixture 'README.md') -Value 'README'
    Set-Content -LiteralPath (Join-Path $Fixture 'LICENSE') -Value 'LICENSE'
    Set-Content -LiteralPath (Join-Path $Fixture 'runner.ps1') -Encoding UTF8 -Value @'
param($Script, $Command, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Directories = @())
$ErrorActionPreference = 'Stop'
function wsl.exe { throw 'WSL must not be invoked' }
function bash { throw 'Bash must not be invoked' }
function Record-Call($Name, $Arguments) {
    @{ Name = $Name; Args = @($Arguments); Cwd = (Get-Location).Path } | ConvertTo-Json -Compress | Add-Content -LiteralPath $env:HFM_TEST_LOG
    $global:LASTEXITCODE = if ($env:HFM_TEST_FAIL -eq $Name) { 7 } else { 0 }
}
function stack {
    Record-Call 'stack' $args
    if ($global:LASTEXITCODE -eq 0 -and $args -contains '--copy-bins') {
        $bin = $args[[array]::IndexOf($args, '--local-bin-path') + 1]
        New-Item -ItemType Directory -Path $bin -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $bin 'hfm-exe.exe') -Value 'fixture executable'
    }
}
function python { Record-Call 'python' $args }
function makensis {
    Record-Call 'makensis' $args
    if ($global:LASTEXITCODE -eq 0) {
        $out = ($args | Where-Object { $_ -like '/DOUTPUT=*' }).Substring(9)
        Set-Content -LiteralPath $out -Value 'fixture installer'
    }
}
& (Join-Path $PSScriptRoot "scripts/$Script") $Command @Directories
exit $LASTEXITCODE
'@

    $result = Invoke-Fixture 'run.ps1' 'run' @('.', '..')
    Assert ($result.Code -eq 0) "Native run failed: $($result.Output)"
    Assert ($result.Calls.Count -eq 1 -and $result.Calls[0].Name -eq 'stack') 'Run must call Stack directly'
    Assert (($result.Calls[0].Args[0..3] -join '|') -eq 'run|hfm-exe|--|' + (Get-Location).Path) 'Starting directory must resolve before changing location'
    Assert ($result.Calls[0].Cwd -eq $Fixture) 'Stack must run from the project root'

    foreach ($command in 'build', 'clean') {
        $result = Invoke-Fixture 'run.ps1' $command
        Assert ($result.Code -eq 0 -and $result.Calls[0].Args[0] -eq $command) "$command did not reach Stack: $($result | ConvertTo-Json -Depth 5 -Compress)"
    }
    $result = Invoke-Fixture 'run.ps1' 'all'
    Assert ($result.Code -eq 0 -and ($result.Calls.Name -join ',') -eq 'stack,python,python,stack,stack') 'All must build, check architecture, test, then run'
    $result = Invoke-Fixture 'run.ps1' 'all' -Fail 'python'
    Assert ($result.Code -eq 7 -and $result.Calls.Count -eq 2) 'A failed check must stop all and preserve its exit code'
    $result = Invoke-Fixture 'run.ps1' 'run' -Fail 'stack'
    Assert ($result.Code -eq 7) 'Run must preserve the executable exit code'
    $result = Invoke-Fixture 'run.ps1' 'build' @('.')
    Assert ($result.Code -ne 0 -and $result.Calls.Count -eq 0) 'Build must reject directory arguments'
    $result = Invoke-Fixture 'run.ps1' 'run' @('.', '.', '.')
    Assert ($result.Code -ne 0 -and $result.Calls.Count -eq 0) 'Run must reject more than two directories'
    $result = Invoke-Fixture 'run.ps1' 'run' @((Join-Path $Fixture 'README.md'))
    Assert ($result.Code -ne 0 -and $result.Calls.Count -eq 0) 'Run must reject files as starting directories'
    $result = Invoke-Fixture 'run.ps1' 'help'
    Assert ($result.Code -eq 0 -and $result.Calls.Count -eq 0) 'Help must not require a build tool'

    $result = Invoke-Fixture 'release.ps1' 'auto'
    Assert ($result.Code -eq 0) "Native release failed: $($result.Output)"
    Assert (($result.Calls.Name -join ',') -eq 'stack,makensis') 'Release must build and invoke NSIS directly'
    Assert (Test-Path -LiteralPath (Join-Path $Fixture 'dist/release/hfm-0.1.0.0-windows-setup.exe')) 'Release must produce a versioned installer'
    $result = Invoke-Fixture 'release.ps1' 'nsis' -Fail 'stack'
    Assert ($result.Code -eq 7 -and $result.Calls.Count -eq 1) 'A failed release build must not package a stale binary'
    $result = Invoke-Fixture 'release.ps1' 'nsis' -Fail 'makensis'
    Assert ($result.Code -eq 7) 'Release must preserve the NSIS exit code'
    Set-Content -LiteralPath (Join-Path $Fixture 'dist/keep.txt') -Value 'unrelated artifact'
    $result = Invoke-Fixture 'release.ps1' 'clean'
    Assert ($result.Code -eq 0 -and $result.Calls.Count -eq 0) 'Release clean must not require build tools'
    Assert (-not (Test-Path -LiteralPath (Join-Path $Fixture 'dist/release'))) 'Clean must remove release artifacts'
    Assert (Test-Path -LiteralPath (Join-Path $Fixture 'dist/keep.txt')) 'Clean must preserve unrelated files'
    $junction = Join-Path $Fixture 'dist/release'
    New-Item -ItemType Junction -Path $junction -Target (Join-Path $Fixture 'apps') | Out-Null
    try {
        $result = Invoke-Fixture 'release.ps1' 'clean'
        Assert ($result.Code -ne 0) 'Clean must reject junctions'
        Assert (Test-Path -LiteralPath (Join-Path $Fixture 'apps/hfm/package.yaml')) 'Clean must preserve junction targets'
    }
    finally { [IO.Directory]::Delete($junction) }
    Write-Host 'PowerShell script checks passed'
}
finally {
    # Only delete the unique temporary fixture created by this test.
    if ([IO.Path]::GetFullPath($Fixture).StartsWith([IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $Fixture -Recurse -Force -ErrorAction SilentlyContinue
    }
    Remove-Item Env:HFM_TEST_LOG, Env:HFM_TEST_FAIL -ErrorAction SilentlyContinue
}
