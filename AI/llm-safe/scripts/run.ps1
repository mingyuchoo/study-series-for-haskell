$ErrorActionPreference = 'Stop'
$applicationArguments = @($args)
$projectRoot = Split-Path -Parent $PSScriptRoot

function Invoke-CheckedCommand {
    param (
        [Parameter(Mandatory = $true)]
        [string] $Command,
        [string[]] $CommandArguments = @()
    )

    & $Command @CommandArguments
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

foreach ($tool in @('stack', 'fourmolu', 'hlint')) {
    if (-not (Get-Command -Name $tool -CommandType Application -ErrorAction SilentlyContinue)) {
        [Console]::Error.WriteLine("Required tool not found: $tool")
        [Console]::Error.WriteLine('Install Stack and run: stack install fourmolu hlint')
        exit 127
    }
}

Push-Location -LiteralPath $projectRoot
try {
    Write-Host "`n[1/5] Formatting Haskell sources"
    $sourceFiles = Get-ChildItem -LiteralPath 'src', 'app', 'test' -Recurse -File |
        Where-Object { $_.Extension -in @('.hs', '.lhs') }
    foreach ($sourceFile in $sourceFiles) {
        Invoke-CheckedCommand -Command 'fourmolu' -CommandArguments @(
            '--mode', 'inplace', '--config', 'fourmolu.yaml', $sourceFile.FullName
        )
    }

    Write-Host "`n[2/5] Linting Haskell sources"
    Invoke-CheckedCommand -Command 'hlint' -CommandArguments @(
        '--extension=ImportQualifiedPost', 'src', 'app', 'test'
    )

    Write-Host "`n[3/5] Building"
    Invoke-CheckedCommand -Command 'stack' -CommandArguments @('build')

    Write-Host "`n[4/5] Running tests"
    Invoke-CheckedCommand -Command 'stack' -CommandArguments @('test')

    Write-Host "`n[5/5] Starting llm-safe-exe"
    Invoke-CheckedCommand -Command 'stack' -CommandArguments (
        @('exec', '--', 'llm-safe-exe') + $applicationArguments
    )
}
finally {
    Pop-Location
}
