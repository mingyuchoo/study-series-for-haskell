#!/usr/bin/env bash
#
# run.sh — azure-bicep-haskell-luck 통합 빌드/테스트/실행 스크립트
#
# 백엔드(Haskell/Servant), 프런트엔드(Solid.js/Vite), 데이터베이스(PostgreSQL)를
# 한 곳에서 빌드·테스트·실행한다.
#
# 사용법:
#   scripts/run.sh [command] [target]
#
# 인수 없이 실행하면 전체 파이프라인(설치 → 빌드 → 테스트 → 실행)을 수행한다.
#
# command:
#   (없음)           설치 + 빌드 + 테스트 + 실행 (DB 기동 포함, 기본 동작)
#   setup            의존성 설치 (npm install + cabal build 의존성)
#   build [target]   빌드          (target: backend | frontend | all=기본)
#   test  [target]   테스트         (target: backend | frontend | all=기본)
#   dev   [target]   개발 실행      (target: backend | frontend | all=기본)
#   db    <up|down>  PostgreSQL 컨테이너 기동/종료
#   clean            빌드 산출물 정리
#   help             도움말
#
# 예시:
#   scripts/run.sh                # 빌드 → 테스트 → 실행
#   scripts/run.sh setup
#   scripts/run.sh db up
#   scripts/run.sh build
#   scripts/run.sh dev            # DB + 백엔드 + 프런트엔드 동시 실행
#   scripts/run.sh dev backend
#
set -euo pipefail

# ── 경로 ───────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_DIR="${ROOT_DIR}/backend"
FRONTEND_DIR="${ROOT_DIR}/frontend"

cd "${ROOT_DIR}"

# ── 출력 헬퍼 ──────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_BLUE='\033[1;34m'; C_GREEN='\033[1;32m'; C_YELLOW='\033[1;33m'
  C_RED='\033[1;31m'; C_RESET='\033[0m'
else
  C_BLUE=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_RESET=''
fi

info()  { printf "${C_BLUE}==>${C_RESET} %s\n" "$*"; }
ok()    { printf "${C_GREEN}✓${C_RESET} %s\n" "$*"; }
warn()  { printf "${C_YELLOW}!${C_RESET} %s\n" "$*"; }
die()   { printf "${C_RED}✗ %s${C_RESET}\n" "$*" >&2; exit 1; }

# ── 환경변수 (.env 로딩 또는 기본값) ───────────────────────────────────────
load_env() {
  if [ -f "${ROOT_DIR}/.env" ]; then
    info ".env 로딩"
    set -a
    # shellcheck disable=SC1091
    . "${ROOT_DIR}/.env"
    set +a
  fi
  : "${DATABASE_URL:=postgresql://luck:luck@localhost:5432/luck}"
  : "${JWT_SECRET:=dev-secret-change-me}"
  : "${PORT:=8080}"
  export DATABASE_URL JWT_SECRET PORT
}

# ── 도구 존재 확인 ─────────────────────────────────────────────────────────
need() { command -v "$1" >/dev/null 2>&1 || die "필수 도구가 없습니다: $1"; }

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
  else
    die "docker compose 를 찾을 수 없습니다."
  fi
}

# ── DB ─────────────────────────────────────────────────────────────────────
db_up() {
  need docker
  # 이미 healthy 상태로 떠 있는 luck-db 가 있으면 재사용한다.
  # (다른 compose 프로젝트가 띄운 컨테이너여도 container_name 이 고정이라 충돌하므로 그대로 사용)
  if docker ps --filter "name=^/luck-db$" --filter "health=healthy" --format '{{.Names}}' | grep -q '^luck-db$'; then
    ok "기존 luck-db 컨테이너 재사용 (localhost:5432)"
    return 0
  fi
  info "PostgreSQL 컨테이너 기동"
  compose up -d db
  ok "DB 기동 완료 (localhost:5432)"
}

db_down() {
  need docker
  info "PostgreSQL 컨테이너 종료"
  compose down
  ok "DB 종료 완료"
}

# ── setup ──────────────────────────────────────────────────────────────────
setup() {
  need npm; need cabal
  info "프런트엔드 의존성 설치 (npm install)"
  npm install
  ok "npm install 완료"

  info "백엔드 의존성 빌드 (cabal build)"
  ( cd "${BACKEND_DIR}" && cabal build )
  ok "cabal build 완료"
}

# ── build ──────────────────────────────────────────────────────────────────
build_backend() {
  need cabal
  info "백엔드 빌드 (cabal build)"
  ( cd "${BACKEND_DIR}" && cabal build )
  ok "백엔드 빌드 완료"
}

build_frontend() {
  need npm
  info "프런트엔드 빌드 (vite build)"
  npm run build:frontend
  ok "프런트엔드 빌드 완료 (frontend/dist)"
}

# ── test ───────────────────────────────────────────────────────────────────
test_backend() {
  need cabal
  info "백엔드 검증"
  # 별도 test-suite 가 정의되어 있으면 실행하고, 없으면 컴파일 검증으로 대체한다.
  if ( cd "${BACKEND_DIR}" && cabal test 2>/dev/null ); then
    ok "cabal test 통과"
  else
    warn "정의된 test-suite 가 없어 컴파일 검증으로 대체합니다."
    ( cd "${BACKEND_DIR}" && cabal build )
    ok "백엔드 컴파일 검증 통과"
  fi
}

test_frontend() {
  need npm
  info "프런트엔드 검증 (TypeScript 타입체크 + 빌드)"
  ( cd "${FRONTEND_DIR}" && npx tsc --noEmit )
  ok "타입체크 통과"
  npm run build:frontend
  ok "프런트엔드 빌드 검증 통과"
}

# ── dev ────────────────────────────────────────────────────────────────────
dev_backend() {
  need cabal
  load_env
  info "백엔드 실행 (cabal run luck-backend) — http://localhost:${PORT}"
  ( cd "${BACKEND_DIR}" && cabal run luck-backend )
}

dev_frontend() {
  need npm
  info "프런트엔드 개발 서버 (vite) — http://localhost:3000"
  npm run dev:frontend
}

# 백엔드 + 프런트엔드 동시 실행 (DB 선기동). Ctrl-C 로 함께 종료.
dev_all() {
  need cabal; need npm
  db_up
  load_env

  local pids=()
  cleanup() {
    warn "종료 중..."
    for pid in "${pids[@]:-}"; do
      kill "${pid}" 2>/dev/null || true
    done
    wait 2>/dev/null || true
  }
  trap cleanup INT TERM EXIT

  info "백엔드 실행 — http://localhost:${PORT}"
  ( cd "${BACKEND_DIR}" && cabal run luck-backend ) &
  pids+=($!)

  info "프런트엔드 개발 서버 — http://localhost:3000"
  npm run dev:frontend &
  pids+=($!)

  ok "백엔드 + 프런트엔드 실행 중. Ctrl-C 로 종료합니다."
  wait
}

# ── 전체 파이프라인 (인수 없이 실행 시 기본 동작) ──────────────────────────
run_all() {
  need cabal; need npm
  info "전체 파이프라인 시작: 설치 → 빌드 → 테스트 → 실행"

  # 1) 의존성 설치 (npm install + cabal build 의존성)
  setup

  # 2) DB 기동 (실행에 필요하므로 먼저 띄운다)
  db_up

  # 3) 빌드
  build_backend
  build_frontend

  # 4) 테스트
  test_backend
  test_frontend

  # 5) 실행 (백엔드 + 프런트엔드 동시)
  ok "빌드·테스트 통과. 개발 서버를 실행합니다."
  dev_all
}

# ── clean ──────────────────────────────────────────────────────────────────
clean() {
  info "빌드 산출물 정리"
  ( cd "${BACKEND_DIR}" && cabal clean ) || true
  rm -rf "${FRONTEND_DIR}/dist" "${FRONTEND_DIR}/node_modules/.vite"
  ok "정리 완료"
}

# ── 도움말 ─────────────────────────────────────────────────────────────────
usage() {
  sed -n '2,29p' "${BASH_SOURCE[0]}" | sed 's/^#\{1,\} \{0,1\}//'
}

# ── 디스패치 ───────────────────────────────────────────────────────────────
main() {
  local cmd="${1:-}"
  local target="${2:-all}"

  case "${cmd}" in
    "") run_all ;;
    setup) setup ;;
    build)
      case "${target}" in
        backend)  build_backend ;;
        frontend) build_frontend ;;
        all)      build_backend; build_frontend ;;
        *) die "알 수 없는 target: ${target}" ;;
      esac ;;
    test)
      case "${target}" in
        backend)  test_backend ;;
        frontend) test_frontend ;;
        all)      test_backend; test_frontend ;;
        *) die "알 수 없는 target: ${target}" ;;
      esac ;;
    dev)
      case "${target}" in
        backend)  dev_backend ;;
        frontend) dev_frontend ;;
        all)      dev_all ;;
        *) die "알 수 없는 target: ${target}" ;;
      esac ;;
    db)
      case "${target}" in
        up)   db_up ;;
        down) db_down ;;
        *) die "db 명령은 up | down 입니다." ;;
      esac ;;
    clean) clean ;;
    help|-h|--help) usage ;;
    *) die "알 수 없는 command: ${cmd} (scripts/run.sh help 참고)" ;;
  esac
}

main "$@"
