[CmdletBinding(PositionalBinding = $false)]
param(
  [Parameter(Position = 0)]
  [ValidateSet('all', 'check', 'format', 'lint', 'build', 'test', 'run', 'help')]
  [string]$Command = 'all',
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$AppArgs = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Handle native exit codes explicitly on both Windows PowerShell 5.1 and pwsh.
$PSNativeCommandUseErrorActionPreference = $false
$RootDir = Split-Path -Parent $PSScriptRoot
$script:ExitCode = 1

function Show-Usage {
  @'
Usage: ./scripts/run.ps1 [all|check|format|lint|build|test|run|help] [APP_ARGS...]

  all     Format, lint, build, test, then launch the GUI (default)
  check   Format, lint, build, and test without launching the GUI
  format  Format Haskell sources in place using fourmolu.yaml
  lint    Report HLint suggestions; fail if any are found
  build   Build with Stack
  test    Run Stack tests (requires a test suite in package.yaml)
  run     Launch the GUI using Stack
  help    Show this help

Requires Stack and the native GUI libraries listed in README.md.
For format/lint: cabal install fourmolu hlint (add Cabal's bin dir to PATH).
App arguments are supported by all/run only.
Examples: ./scripts/run.ps1; ./scripts/run.ps1 check
          ./scripts/run.ps1 run -AppArgs @('+RTS', '-N2', '-RTS')
'@ | Write-Host
}

function Invoke-Checked {
  param([string]$Tool, [string[]]$ToolArgs)
  & $Tool @ToolArgs
  if ($LASTEXITCODE -ne 0) {
    $script:ExitCode = $LASTEXITCODE
    throw "$Tool failed (exit $LASTEXITCODE)."
  }
}

function Invoke-Stage {
  param([string]$Stage)
  Write-Host "`n==> $Stage"
  switch ($Stage) {
    'format' {
      Invoke-Checked 'fourmolu' (@('--mode', 'inplace', '--ghc-opt=-XImportQualifiedPost', '--ghc-opt=-XOverloadedStrings') + $Sources)
    }
    'lint' {
      Invoke-Checked 'hlint' (@('-XImportQualifiedPost', '-XOverloadedStrings') + $Sources)
    }
    'build' { Invoke-Checked 'stack' @('build') }
    'test' {
      if (-not (Select-String -LiteralPath 'MonomerTodo.cabal' -Pattern '^\s*test-suite\s' -Quiet)) {
        Write-Host 'Note: no test suite is registered; stack test will still be invoked.'
      }
      Invoke-Checked 'stack' @('test')
    }
    'run' { Invoke-Checked 'stack' (@('run', 'MonomerTodo:exe:app', '--') + $AppArgs) }
  }
}

if ($Command -eq 'help') { Show-Usage; exit 0 }
if ($AppArgs.Count -gt 0 -and $AppArgs[0] -eq '--') {
  $AppArgs = @($AppArgs | Select-Object -Skip 1)
}
if ($AppArgs.Count -gt 0 -and $Command -notin @('all', 'run')) {
  [Console]::Error.WriteLine('error: app arguments are only supported by all/run.')
  exit 2
}

Push-Location -LiteralPath $RootDir
try {
  $RequiredTools = switch ($Command) {
    { $_ -in @('all', 'check') } { 'fourmolu'; 'hlint'; 'stack' }
    'format' { 'fourmolu' }
    'lint' { 'hlint' }
    default { 'stack' }
  }
  $Missing = @($RequiredTools | Where-Object { -not (Get-Command $_ -CommandType Application -ErrorAction SilentlyContinue) })
  if ($Missing.Count -gt 0) {
    $script:ExitCode = 127
    Show-Usage
    throw "Required commands not found on PATH: $($Missing -join ', ')"
  }

  $Sources = @()
  if ($Command -in @('all', 'check', 'format', 'lint')) {
    $Files = @(Get-ChildItem -LiteralPath $RootDir -File)
    foreach ($Dir in @('src', 'app', 'test', 'tests')) {
      $SourceDir = Join-Path $RootDir $Dir
      if (Test-Path -LiteralPath $SourceDir -PathType Container) {
        $Files += @(Get-ChildItem -LiteralPath $SourceDir -Recurse -File)
      }
    }
    $Sources = @($Files | Where-Object { $_.Extension -in @('.hs', '.lhs') } | Sort-Object FullName | ForEach-Object { $_.FullName })
    if ($Sources.Count -eq 0) { throw 'No Haskell source files found.' }
  }

  if ($Command -in @('all', 'check')) {
    foreach ($Stage in @('format', 'lint', 'build', 'test')) { Invoke-Stage $Stage }
    if ($Command -eq 'all') { Invoke-Stage 'run' }
  }
  else { Invoke-Stage $Command }
}
catch {
  [Console]::Error.WriteLine("error: $($_.Exception.Message)")
  exit $script:ExitCode
}
finally {
  Pop-Location
}
