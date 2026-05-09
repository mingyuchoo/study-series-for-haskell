$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..")

Set-Location $ProjectRoot

if (-not (Get-Command stack -ErrorAction SilentlyContinue)) {
    Write-Error "stack is required but was not found in PATH"
}

$RunArgs = @($args)
if ($RunArgs.Count -eq 0) {
    $RunArgs = @("-o", "output.svg", "-w", "400")
}

Write-Host "==> Building DiagramsDemo03"
stack build

Write-Host "==> Testing DiagramsDemo03"
stack test

Write-Host "==> Running DiagramsDemo03"
stack run -- @RunArgs
