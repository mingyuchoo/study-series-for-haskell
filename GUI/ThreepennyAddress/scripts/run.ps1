$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$MakeCmd = if ($env:MAKE) { $env:MAKE } else { "make" }

Set-Location $ProjectRoot

& $MakeCmd build
& $MakeCmd test
& $MakeCmd run
