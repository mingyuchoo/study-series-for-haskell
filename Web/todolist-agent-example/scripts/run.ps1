$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

function Invoke-Step {
    param(
        [string]$Message,
        [string]$Executable,
        [string[]]$Arguments
    )

    Write-Host $Message
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

$fourmolu = (Get-Command -Name fourmolu -CommandType Application -TotalCount 1).Source
$hlint = (Get-Command -Name hlint -CommandType Application -TotalCount 1).Source
$stack = (Get-Command -Name stack -CommandType Application -TotalCount 1).Source
$sourceDirectories = @('app', 'src', 'test', 'integration')

Push-Location -LiteralPath (Join-Path $PSScriptRoot '..')
try {
    Invoke-Step 'Formatting Haskell sources' $fourmolu (@('--mode', 'inplace') + $sourceDirectories)
    Invoke-Step 'Linting Haskell sources' $hlint (@('--no-exit-code') + $sourceDirectories)
    Invoke-Step 'Building application and tests' $stack @('build', '--test', '--no-run-tests')
    Invoke-Step 'Running tests' $stack @('test')
    Invoke-Step 'Starting TodoList' $stack @('run', 'todo-list')
} finally {
    Pop-Location
}
