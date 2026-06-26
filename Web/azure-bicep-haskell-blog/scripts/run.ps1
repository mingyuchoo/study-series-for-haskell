#!/usr/bin/env pwsh
<#
.SYNOPSIS
    haskell-blog 빌드 / 테스트 / 로컬 실행 헬퍼.

.DESCRIPTION
    Command 인자에 따라 동작한다:
      build   cabal build (의존성 포함 전체 빌드)
      test    cabal test (테스트 스위트가 있으면 실행, 없으면 건너뜀)
      run     로컬 PostgreSQL(도커)을 띄우고 cabal run 으로 앱 실행
      all     build -> test -> run (기본값)

.PARAMETER Command
    실행할 작업. build | test | run | all (기본값: all)

.EXAMPLE
    ./scripts/run.ps1
    ./scripts/run.ps1 build
    ./scripts/run.ps1 run

.NOTES
    환경 변수:
      PORT          앱 리스닝 포트 (기본 8080)
      DATABASE_URL  지정 시 로컬 도커 PostgreSQL 대신 이 값을 사용
#>
[CmdletBinding()]
param(
    [ValidateSet('build', 'test', 'run', 'all', 'help')]
    [string]$Command = 'all'
)

$ErrorActionPreference = 'Stop'

# 프로젝트 루트(이 스크립트의 상위 디렉터리)로 이동.
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

$Port               = if ($env:PORT) { $env:PORT } else { '8080' }
$DbContainer        = 'haskell-blog-localdb'
$DefaultDatabaseUrl = 'postgresql://blog:blog@localhost:5432/blog?sslmode=disable'

function Write-Log  { param([string]$Message) Write-Host "==> $Message" -ForegroundColor Blue }
function Write-Warn { param([string]$Message) Write-Host "[warn] $Message" -ForegroundColor Yellow }
function Write-Err  { param([string]$Message) Write-Host "[error] $Message" -ForegroundColor Red }

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Err "'$Name' 명령을 찾을 수 없습니다. 설치 후 다시 시도하세요."
        exit 1
    }
}

# postgresql-simple(postgresql-libpq)은 빌드 시 libpq(pg_config)를 요구한다.
# pg_config가 PATH에 없으면 Homebrew 설치 경로를 자동으로 연결해 준다.
function Ensure-PgClient {
    if (Get-Command pg_config -ErrorAction SilentlyContinue) { return }
    if (Get-Command brew -ErrorAction SilentlyContinue) {
        foreach ($pkg in @('libpq', 'postgresql@16', 'postgresql')) {
            $prefix = (brew --prefix $pkg 2>$null)
            if ($prefix -and (Test-Path (Join-Path $prefix 'bin/pg_config'))) {
                $env:PATH = (Join-Path $prefix 'bin') + [IO.Path]::PathSeparator + $env:PATH
                $env:PKG_CONFIG_PATH = (Join-Path $prefix 'lib/pkgconfig') + [IO.Path]::PathSeparator + $env:PKG_CONFIG_PATH
                Write-Log "libpq 경로 연결: $prefix"
                return
            }
        }
    }
    Write-Err 'libpq(pg_config)를 찾을 수 없습니다. postgresql-simple 빌드에 필요합니다.'
    Write-Err '  macOS:   brew install libpq && brew link --force libpq'
    Write-Err '  Windows: PostgreSQL 설치 후 bin 디렉터리를 PATH에 추가하세요.'
    exit 1
}

function Invoke-Build {
    Require-Command cabal
    Ensure-PgClient
    Write-Log '의존성 업데이트 (cabal update)'
    cabal update
    Write-Log '빌드 (cabal build all)'
    cabal build all
    Write-Log '빌드 완료'
}

function Invoke-Test {
    Require-Command cabal
    # .cabal 에 test-suite 스탠자가 있는 경우에만 cabal test 실행.
    $cabalFile = Get-ChildItem -Path . -Filter '*.cabal' | Select-Object -First 1
    if ($cabalFile -and (Select-String -Path $cabalFile.FullName -Pattern '^\s*test-suite\b' -Quiet)) {
        Write-Log '테스트 실행 (cabal test all)'
        cabal test all
        Write-Log '테스트 완료'
    }
    else {
        Write-Warn '정의된 test-suite가 없어 테스트를 건너뜁니다. (.cabal 에 test-suite 추가 시 자동 실행됩니다)'
    }
}

# 로컬 개발용 PostgreSQL 컨테이너를 보장한다 (docker-compose.yml 의 db 설정과 동일).
function Ensure-LocalDb {
    Require-Command docker
    $running = docker ps --format '{{.Names}}'
    $all     = docker ps -a --format '{{.Names}}'

    if ($running -contains $DbContainer) {
        Write-Log "로컬 PostgreSQL($DbContainer) 이미 실행 중"
    }
    elseif ($all -contains $DbContainer) {
        Write-Log '기존 PostgreSQL 컨테이너 시작'
        docker start $DbContainer | Out-Null
    }
    else {
        Write-Log '로컬 PostgreSQL 컨테이너 시작 (postgres:16)'
        docker run -d --name $DbContainer `
            -e POSTGRES_USER=blog `
            -e POSTGRES_PASSWORD=blog `
            -e POSTGRES_DB=blog `
            -p 5432:5432 `
            postgres:16 | Out-Null
    }

    Write-Log 'PostgreSQL 준비 대기 중...'
    for ($i = 0; $i -lt 30; $i++) {
        docker exec $DbContainer pg_isready -U blog *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Log 'PostgreSQL 준비 완료'
            return
        }
        Start-Sleep -Seconds 1
    }
    Write-Err 'PostgreSQL 가 제한 시간 내에 준비되지 않았습니다.'
    exit 1
}

function Invoke-Run {
    Require-Command cabal
    Ensure-PgClient
    if ($env:DATABASE_URL) {
        Write-Log '외부 DATABASE_URL 사용 (로컬 도커 DB 생략)'
    }
    else {
        Ensure-LocalDb
        $env:DATABASE_URL = $DefaultDatabaseUrl
    }
    $env:PORT = $Port
    # PREVIEW_SECRET 가 없으면 로컬 개발용 기본키 사용을 명시적으로 허용한다.
    # (앱은 fail-closed — 미허용 시 기동을 거부한다. 프로덕션은 PREVIEW_SECRET 를 설정.)
    if (-not $env:PREVIEW_SECRET) {
        Write-Warn 'PREVIEW_SECRET 미설정 — 로컬 개발용 기본키 사용(ALLOW_INSECURE_SECRET=1). 프로덕션에서는 PREVIEW_SECRET 를 설정하세요.'
        if (-not $env:ALLOW_INSECURE_SECRET) { $env:ALLOW_INSECURE_SECRET = '1' }
    }
    Write-Log "앱 실행: http://localhost:$Port  (종료: Ctrl+C)"
    cabal run haskell-blog
}

switch ($Command) {
    'build' { Invoke-Build }
    'test'  { Invoke-Test }
    'run'   { Invoke-Run }
    'all'   { Invoke-Build; Invoke-Test; Invoke-Run }
    'help'  { Get-Help $MyInvocation.MyCommand.Path -Detailed }
}
