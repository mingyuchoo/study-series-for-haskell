#requires -Version 7.3

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandArgumentPassing = 'Standard'

function Invoke-Stage {
    param (
        [string] $Name,
        [string] $Command,
        [string[]] $CommandArguments
    )

    Write-Host "`n==> $Name"
    & $Command @CommandArguments
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

$applicationArguments = @($args)
$projectRoot = Split-Path -Parent $PSScriptRoot

Push-Location -LiteralPath $projectRoot
try {
    foreach ($tool in @('stack', 'fourmolu', 'hlint')) {
        if (-not (Get-Command -Name $tool -CommandType Application -ErrorAction SilentlyContinue)) {
            [Console]::Error.WriteLine("Required tool not found in PATH: $tool")
            [Console]::Error.WriteLine('Install Stack, then run: stack install fourmolu hlint')
            exit 127
        }
    }

    $sourceFiles = @('Setup.hs') + @(
        Get-ChildItem -LiteralPath 'src', 'app', 'test' -Recurse -File -Filter '*.hs' |
            Sort-Object -Property FullName |
            Select-Object -ExpandProperty FullName
    )

    Invoke-Stage -Name 'Formatting' -Command 'fourmolu' -CommandArguments (@('--mode', 'inplace') + $sourceFiles)
    Invoke-Stage -Name 'Linting' -Command 'hlint' -CommandArguments $sourceFiles
    Invoke-Stage -Name 'Building' -Command 'stack' -CommandArguments @('build')
    Invoke-Stage -Name 'Testing' -Command 'stack' -CommandArguments @('test')
    Invoke-Stage -Name 'Running' -Command 'stack' -CommandArguments (@('exec', 'MySaju-exe', '--') + $applicationArguments)
}
finally {
    Pop-Location
}
