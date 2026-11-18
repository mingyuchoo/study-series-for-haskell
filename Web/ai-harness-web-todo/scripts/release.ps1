param(
    [string]$OutputDirectory,
    [ValidateSet('inplace', 'check')]
    [string]$Format = 'inplace',
    [switch]$Check,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $python = Get-Command python -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $python) {
        $python = Get-Command python3 -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($null -eq $python) {
        throw 'Python 3.11 or newer is required. See docs/RELEASE.md'
    }
    $releaseArguments = @((Join-Path $PSScriptRoot 'release/release.py'), '--format', $Format)
    if ($OutputDirectory) {
        $releaseArguments += @('--output', $OutputDirectory)
    }
    if ($Check) {
        $releaseArguments += '--check'
    }
    if ($Help) {
        $releaseArguments += '--help'
    }
    & $python.Source @releaseArguments
    exit $LASTEXITCODE
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
