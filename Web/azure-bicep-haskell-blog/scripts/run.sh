#!/usr/bin/env bash
#
# haskell-blog 빌드 / 테스트 / 로컬 실행 헬퍼.
#
# 사용법:
#   scripts/run.sh [command]
#
# command:
#   build   cabal build (의존성 포함 전체 빌드)
#   test    cabal test (테스트 스위트가 있으면 실행, 없으면 건너뜀)
#   run     로컬 PostgreSQL(도커)을 띄우고 cabal run 으로 앱 실행
#   all     build → test → run (기본값)
#
# 환경 변수:
#   PORT          앱 리스닝 포트 (기본 8080)
#   DATABASE_URL  지정 시 로컬 도커 PostgreSQL 대신 이 값을 사용
set -euo pipefail

# 프로젝트 루트(이 스크립트의 상위 디렉터리)로 이동.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

PORT="${PORT:-8080}"
DB_CONTAINER="haskell-blog-localdb"
DEFAULT_DATABASE_URL="postgresql://blog:blog@localhost:5432/blog?sslmode=disable"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; }

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "'$1' 명령을 찾을 수 없습니다. 설치 후 다시 시도하세요."
    exit 1
  fi
}

# postgresql-simple(postgresql-libpq)은 빌드 시 libpq(pg_config)를 요구한다.
# pg_config가 PATH에 없으면 Homebrew 설치 경로를 자동으로 연결해 준다.
ensure_pg_client() {
  if command -v pg_config >/dev/null 2>&1; then
    return 0
  fi
  if command -v brew >/dev/null 2>&1; then
    for pkg in libpq postgresql@16 postgresql; do
      local prefix
      prefix="$(brew --prefix "${pkg}" 2>/dev/null || true)"
      if [[ -n "${prefix}" && -x "${prefix}/bin/pg_config" ]]; then
        export PATH="${prefix}/bin:${PATH}"
        export PKG_CONFIG_PATH="${prefix}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
        log "libpq 경로 연결: ${prefix}"
        return 0
      fi
    done
  fi
  err "libpq(pg_config)를 찾을 수 없습니다. postgresql-simple 빌드에 필요합니다."
  err "  macOS:  brew install libpq && brew link --force libpq"
  err "  Debian: sudo apt-get install -y libpq-dev"
  exit 1
}

cmd_build() {
  require cabal
  ensure_pg_client
  log "의존성 업데이트 (cabal update)"
  cabal update
  log "빌드 (cabal build all)"
  cabal build all
  log "빌드 완료"
}

cmd_test() {
  require cabal
  # haskell-blog.cabal 에 test-suite 스탠자가 있는 경우에만 cabal test 실행.
  if grep -qiE '^\s*test-suite\b' ./*.cabal 2>/dev/null; then
    log "테스트 실행 (cabal test all)"
    cabal test all
    log "테스트 완료"
  else
    warn "정의된 test-suite가 없어 테스트를 건너뜁니다. (.cabal 에 test-suite 추가 시 자동 실행됩니다)"
  fi
}

# 로컬 개발용 PostgreSQL 컨테이너를 보장한다 (docker-compose.yml 의 db 설정과 동일).
ensure_local_db() {
  require docker
  if docker ps --format '{{.Names}}' | grep -qx "${DB_CONTAINER}"; then
    log "로컬 PostgreSQL(${DB_CONTAINER}) 이미 실행 중"
  elif docker ps -a --format '{{.Names}}' | grep -qx "${DB_CONTAINER}"; then
    log "기존 PostgreSQL 컨테이너 시작"
    docker start "${DB_CONTAINER}" >/dev/null
  else
    log "로컬 PostgreSQL 컨테이너 시작 (postgres:16)"
    docker run -d --name "${DB_CONTAINER}" \
      -e POSTGRES_USER=blog \
      -e POSTGRES_PASSWORD=blog \
      -e POSTGRES_DB=blog \
      -p 5432:5432 \
      postgres:16 >/dev/null
  fi

  log "PostgreSQL 준비 대기 중..."
  for _ in $(seq 1 30); do
    if docker exec "${DB_CONTAINER}" pg_isready -U blog >/dev/null 2>&1; then
      log "PostgreSQL 준비 완료"
      return 0
    fi
    sleep 1
  done
  err "PostgreSQL 가 제한 시간 내에 준비되지 않았습니다."
  exit 1
}

cmd_run() {
  require cabal
  ensure_pg_client
  if [[ -n "${DATABASE_URL:-}" ]]; then
    log "외부 DATABASE_URL 사용 (로컬 도커 DB 생략)"
  else
    ensure_local_db
    export DATABASE_URL="${DEFAULT_DATABASE_URL}"
  fi
  export PORT
  log "앱 실행: http://localhost:${PORT}  (종료: Ctrl+C)"
  cabal run haskell-blog
}

main() {
  local command="${1:-all}"
  case "${command}" in
    build) cmd_build ;;
    test)  cmd_test ;;
    run)   cmd_run ;;
    all)
      cmd_build
      cmd_test
      cmd_run
      ;;
    -h|--help|help)
      sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      ;;
    *)
      err "알 수 없는 명령: ${command}"
      err "사용 가능한 명령: build | test | run | all (기본값: all)"
      exit 1
      ;;
  esac
}

main "$@"
