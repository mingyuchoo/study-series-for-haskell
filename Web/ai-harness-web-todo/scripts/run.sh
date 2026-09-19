#!/usr/bin/env bash
set -euo pipefail

# 저장소 루트에서 전체 코드베이스의 포맷팅, 빌드, 테스트, 실행을 총괄하는 진입점 스크립트입니다.
#
# 패키지별 빌드와 테스트 방법의 Canonical Source는 각 패키지의 지역 스크립트
# (src/<패키지>/scripts/run.sh)입니다. 이 스크립트는 중복 정의 없이 그 스크립트들에 일을 위임하고
# 결과를 모아 보여줍니다.
#
# 저장소 전체 검증(형식, 아키텍처 규칙, 컨텍스트 무결성)은 quality/ 및 context/ 스크립트와 연계합니다.
#
# 서버는 127.0.0.1에만 바인딩하며 이 스크립트가 수신 주소를 바꿀 수 없습니다.
# 그것은 설정이 아니라 경계입니다 (docs/decisions/ADR-0004-web-surface.md).

original_pwd="$PWD"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src_root="$repo_root/src"
cd "$repo_root"

web_package="web"
api_package="api"
default_web_port=8081
default_api_port=8080
default_database="$repo_root/todo.db"

# 패키지는 자기 이름과 같은 cabal 파일을 가진 디렉터리로 정의합니다.
packages() {
  local directory name
  for directory in "$src_root"/*; do
    [[ -d "$directory" ]] || continue
    name="$(basename "$directory")"
    [[ -f "$directory/$name.cabal" ]] || continue
    printf '%s\n' "$name"
  done
}

executables_of() {
  awk '/^executable[[:space:]]+/ { print $2 }' "$src_root/$1/$1.cabal"
}

runnable_packages() {
  local package
  for package in $(packages); do
    if [[ -n "$(executables_of "$package")" ]]; then
      printf '%s\n' "$package"
    fi
  done
}

package_script() {
  printf '%s\n' "$src_root/$1/scripts/run.sh"
}

collect_hs_files() {
  find src -name '*.hs' -not -path '*/dist-newstyle/*'
}

# 상대 경로는 사용자가 스크립트를 실행한 위치를 기준으로 풉니다.
absolute_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "$original_pwd" "$1" ;;
  esac
}

require_port() {
  local label="$1" value="$2"
  if [[ ! "$value" =~ ^[0-9]+$ ]] || ((value < 1 || value > 65535)); then
    printf '%s 포트가 올바르지 않습니다: %s\n' "$label" "$value" >&2
    exit 2
  fi
}

# bash 내장 /dev/tcp로 확인합니다. lsof나 nc가 없는 환경에서도 동작합니다.
port_in_use() {
  (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
}

require_free_port() {
  local label="$1" port="$2"
  if port_in_use "$port"; then
    printf '%s 포트를 이미 무언가 사용하고 있습니다: %s\n' "$label" "$port" >&2
    printf '다른 포트를 지정하거나 그 프로세스를 먼저 종료하십시오.\n' >&2
    exit 1
  fi
}

usage() {
  cat <<USAGE
사용법: scripts/run.sh [명령] [옵션...]

명령
  all [옵션...]        포맷팅, 빌드, 테스트를 순서대로 수행합니다 (기본값)
  format, fmt [옵션]  Haskell 소스 코드의 형식을 맞춥니다 (fourmolu)
  build [패키지...]    패키지를 빌드합니다 (인자 없으면 전체)
  test [패키지...]     패키지의 테스트를 실행합니다 (인자 없으면 전체)
  web [옵션...]        브라우저 표면을 빌드하고 기동합니다
  cli [인자...]        명령줄 인터페이스(cli)를 실행합니다
  api [인자...]        HTTP API 서버(api)를 실행합니다
  run [패키지] [인자]  지정한 앱을 실행합니다 (기본값: web)
  list                 패키지와 실행 가능 여부를 보여줍니다
  lint [인자...]       형식, 정적 제안, GHC 무경고, 셸 문법을 검사합니다
  check                린트, 테스트, 아키텍처 규칙, 컨텍스트 무결성을 모두 검증합니다
  help                 이 도움말을 출력합니다

format 옵션
  --check              파일을 수정하지 않고 형식 준수 여부만 검사합니다
  --inplace, -i        파일을 직접 수정하여 형식을 맞춥니다 (기본값)

all 옵션
  --run[=앱]           검증 완료 후 지정한 앱(기본값: web)을 실행합니다
  --no-format          포맷팅 단계를 건너뜁니다
  --no-test            테스트 단계를 건너뜁니다

web 옵션
  --port N             수신 포트 (기본값: $default_web_port)
  --db PATH            SQLite 파일 경로 (기본값: $default_database)
  --with-api           HTTP API도 함께 기동합니다 (기본 포트: $default_api_port)
  --api-port N         API 수신 포트
  --test               기동 전에 모든 패키지의 테스트를 실행합니다
  --no-build           빌드를 건너뜁니다

예시
  scripts/run.sh                     # 포맷팅 -> 빌드 -> 테스트 순서로 실행
  scripts/run.sh format              # 전체 소스 코드 포맷팅
  scripts/run.sh format --check      # 포맷팅 검사만 수행
  scripts/run.sh build               # 전체 패키지 빌드
  scripts/run.sh test                # 전체 테스트 실행
  scripts/run.sh all --run           # 포맷팅, 빌드, 테스트 후 웹 UI 자동 기동
  scripts/run.sh web                 # 브라우저 UI 기동 (http://127.0.0.1:8081)
  scripts/run.sh web --test --with-api # 테스트 후 웹 UI와 API 동시 기동
  scripts/run.sh cli -- add "할 일"  # CLI로 새 할 일 추가
  scripts/run.sh cli -- list --all   # CLI로 할 일 목록 조회
  scripts/run.sh run cli -- list
  scripts/run.sh check               # 전체 품질 및 컨텍스트 무결성 검증

서버는 127.0.0.1에만 바인딩합니다. 이 앱에는 인증이 없어 접근 경로 제한이
유일한 방어선이며, 수신 주소를 바꾸는 설정은 제공하지 않습니다.
USAGE
}

passed=""
failed=""

for_each_package() {
  local action="$1"
  shift
  local targets=()
  if [[ "$#" -gt 0 ]]; then
    targets=("$@")
  else
    mapfile -t targets < <(packages)
  fi

  passed=""
  failed=""

  for package in "${targets[@]}"; do
    local script
    script="$(package_script "$package")"
    printf '\n==== %s: %s ====\n' "$package" "$action"
    if [[ ! -x "$script" ]]; then
      printf '지역 스크립트를 실행할 수 없습니다: %s\n' "$script" >&2
      failed="$failed $package"
      continue
    fi
    if "$script" "$action"; then
      passed="$passed $package"
    else
      failed="$failed $package"
    fi
  done
}

report() {
  local action="$1"
  printf '\n==== 요약: %s ====\n' "$action"
  if [[ -n "$passed" ]]; then
    printf '통과:%s\n' "$passed"
  fi
  if [[ -n "$failed" ]]; then
    printf '실패:%s\n' "$failed" >&2
    return 1
  fi
  return 0
}

format_code() {
  local mode="inplace"
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --check)
        mode="check"
        shift
        ;;
      --inplace | -i)
        mode="inplace"
        shift
        ;;
      *)
        printf 'format 명령이 모르는 옵션입니다: %s\n\n' "$1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done

  if ! command -v fourmolu >/dev/null 2>&1; then
    printf 'fourmolu를 찾을 수 없습니다. 포맷팅을 건너뜁니다.\n' >&2
    printf 'fourmolu를 설치하려면 `cabal install fourmolu` 또는 ghcup을 사용하십시오.\n' >&2
    return 1
  fi

  local files
  mapfile -t files < <(collect_hs_files)
  if [[ ${#files[@]} -eq 0 ]]; then
    printf '포맷팅할 Haskell 소스 파일이 없습니다.\n'
    return 0
  fi

  if [[ "$mode" == "check" ]]; then
    printf '==== Haskell 코드 형식 검사 (fourmolu --mode check) ====\n'
    fourmolu --mode check "${files[@]}"
    printf 'fourmolu 형식 검사 통과 (%d개 파일)\n' "${#files[@]}"
  else
    printf '==== Haskell 코드 포맷팅 적용 (fourmolu --mode inplace) ====\n'
    fourmolu --mode inplace "${files[@]}"
    printf 'fourmolu 코드 포맷팅 완료 (%d개 파일)\n' "${#files[@]}"
  fi
}

build_packages() {
  for_each_package build "$@"
  report build
}

test_packages() {
  for_each_package test "$@"
  report test
}

list_packages() {
  printf '패키지 / 실행 파일 / 지역 스크립트\n\n'
  for package in $(packages); do
    executable="$(executables_of "$package" | awk 'NR == 1')"
    printf '%-12s %-10s %s\n' \
      "$package" \
      "${executable:--}" \
      "src/$package/scripts/run.sh"
  done
}

run_web() {
  local web_port="${TODO_WEB_PORT:-$default_web_port}"
  local api_port="${TODO_API_PORT:-$default_api_port}"
  local database="${TODO_DB:-$default_database}"
  local with_api=0
  local run_tests=0
  local do_build=1

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --port)
        web_port="${2:-}"
        shift 2
        ;;
      --port=*)
        web_port="${1#*=}"
        shift
        ;;
      --api-port)
        api_port="${2:-}"
        shift 2
        ;;
      --api-port=*)
        api_port="${1#*=}"
        shift
        ;;
      --db)
        database="${2:-}"
        shift 2
        ;;
      --db=*)
        database="${1#*=}"
        shift
        ;;
      --with-api)
        with_api=1
        shift
        ;;
      --test)
        run_tests=1
        shift
        ;;
      --no-build)
        do_build=0
        shift
        ;;
      *)
        printf 'web 명령이 모르는 옵션입니다: %s\n\n' "$1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done

  if [[ -z "$database" ]]; then
    printf '데이터베이스 경로가 비어 있습니다.\n' >&2
    exit 2
  fi
  database="$(absolute_path "$database")"
  require_port "웹" "$web_port"
  if [[ "$with_api" -eq 1 ]]; then
    require_port "API" "$api_port"
    if [[ "$web_port" == "$api_port" ]]; then
      printf '웹과 API가 같은 포트를 쓸 수 없습니다: %s\n' "$web_port" >&2
      exit 2
    fi
  fi

  if [[ "$do_build" -eq 1 ]]; then
    printf '\n==== %s: build ====\n' "$web_package"
    "$(package_script "$web_package")" build
    if [[ "$with_api" -eq 1 ]]; then
      printf '\n==== %s: build ====\n' "$api_package"
      "$(package_script "$api_package")" build
    fi
  fi

  if [[ "$run_tests" -eq 1 ]]; then
    test_packages
  fi

  require_free_port "웹" "$web_port"
  [[ "$with_api" -eq 1 ]] && require_free_port "API" "$api_port"

  export TODO_DB="$database"
  export TODO_WEB_PORT="$web_port"
  export TODO_API_PORT="$api_port"

  printf '\n==== 기동 ====\n'
  printf '  브라우저   http://127.0.0.1:%s\n' "$web_port"
  if [[ "$with_api" -eq 1 ]]; then
    printf '  HTTP API   http://127.0.0.1:%s/todos\n' "$api_port"
  fi
  printf '  데이터     %s\n' "$database"
  printf '  종료       Ctrl+C\n\n'

  if [[ "$with_api" -eq 0 ]]; then
    exec "$(package_script "$web_package")" run
  fi

  set -m

  local api_pid=""
  local web_pid=""

  signal_servers() {
    local signal="$1" pid
    for pid in "$web_pid" "$api_pid"; do
      [[ -n "$pid" ]] || continue
      if ! kill "-$signal" -- "-$pid" 2>/dev/null; then
        kill "-$signal" "$pid" 2>/dev/null || true
      fi
    done
  }

  servers_alive() {
    local pid
    for pid in "$web_pid" "$api_pid"; do
      [[ -n "$pid" ]] || continue
      if kill -0 "$pid" 2>/dev/null; then
        return 0
      fi
    done
    return 1
  }

  stop_servers() {
    trap - EXIT INT TERM
    signal_servers TERM

    local attempt
    for attempt in $(seq 1 20); do
      if ! servers_alive; then
        return 0
      fi
      sleep 0.25
    done

    printf '서버가 제때 종료하지 않아 강제로 정리합니다.\n' >&2
    signal_servers KILL
  }
  trap stop_servers EXIT INT TERM

  "$(package_script "$api_package")" run &
  api_pid="$!"

  "$(package_script "$web_package")" run &
  web_pid="$!"

  wait "$web_pid" || true
}

run_package() {
  local target="${1:-web}"
  if [[ "$#" -gt 0 ]]; then
    shift
  fi

  if [[ -z "$target" ]]; then
    printf '실행할 앱을 지정하십시오.\n\n' >&2
    printf '실행 가능한 앱:\n' >&2
    runnable_packages | sed 's/^/  /' >&2
    printf '\n예: scripts/run.sh run cli -- list\n' >&2
    exit 2
  fi

  case "$target" in
    web)
      run_web "$@"
      return
      ;;
  esac

  if [[ ! -f "$src_root/$target/$target.cabal" ]]; then
    printf '그런 패키지가 없습니다: %s\n' "$target" >&2
    exit 2
  fi

  if [[ -z "$(executables_of "$target")" ]]; then
    printf '%s는 라이브러리 전용 패키지여서 실행할 수 없습니다.\n\n' "$target" >&2
    printf '실행 가능한 앱:\n' >&2
    runnable_packages | sed 's/^/  /' >&2
    exit 1
  fi

  if [[ "${1:-}" == "--" ]]; then
    shift
  fi

  exec "$(package_script "$target")" run -- "$@"
}

run_all() {
  local do_format=1
  local do_test=1
  local run_target=""
  local extra_args=()

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --no-format)
        do_format=0
        shift
        ;;
      --no-test)
        do_test=0
        shift
        ;;
      --run)
        run_target="web"
        shift
        ;;
      --run=*)
        run_target="${1#*=}"
        shift
        ;;
      *)
        extra_args+=("$1")
        shift
        ;;
    esac
  done

  if [[ "$do_format" -eq 1 ]]; then
    format_code --inplace
  fi

  build_packages "${extra_args[@]}"

  if [[ "$do_test" -eq 1 ]]; then
    test_packages "${extra_args[@]}"
  fi

  printf '\n========================================\n'
  printf '포맷팅, 빌드, 테스트 단계 완료\n'
  printf '========================================\n'

  if [[ -n "$run_target" ]]; then
    printf '\n앱을 기동합니다: %s\n' "$run_target"
    run_package "$run_target"
  fi
}

check_all() {
  printf '==== 1/4: 린트 및 형식 검사 ====\n'
  "$repo_root/scripts/quality/lint.sh"
  printf '\n==== 2/4: 전체 테스트 실행 ====\n'
  "$repo_root/scripts/quality/test.sh"
  printf '\n==== 3/4: 아키텍처 규칙 검사 ====\n'
  "$repo_root/scripts/quality/architecture-check.sh"
  printf '\n==== 4/4: 컨텍스트 무결성 검사 ====\n'
  "$repo_root/scripts/context/validate-context.sh"
  printf '\n저장소의 모든 품질 및 컨텍스트 검증을 통과했습니다.\n'
}

command_name="${1:-all}"
if [[ "$#" -gt 0 ]]; then
  shift
fi

case "$command_name" in
  help | -h | --help)
    usage
    ;;

  format | fmt)
    format_code "$@"
    ;;

  build)
    build_packages "$@"
    ;;

  test)
    test_packages "$@"
    ;;

  all)
    run_all "$@"
    ;;

  run)
    run_package "$@"
    ;;

  web)
    run_web "$@"
    ;;

  cli)
    if [[ "${1:-}" == "--" ]]; then
      shift
    fi
    run_package cli -- "$@"
    ;;

  api)
    if [[ "${1:-}" == "--" ]]; then
      shift
    fi
    run_package api -- "$@"
    ;;

  lint)
    "$repo_root/scripts/quality/lint.sh" "$@"
    ;;

  check)
    check_all
    ;;

  list)
    list_packages
    ;;

  *)
    printf '알 수 없는 명령입니다: %s\n\n' "$command_name" >&2
    usage >&2
    exit 2
    ;;
esac
