#!/usr/bin/env bash
set -euo pipefail

# 이 패키지 하나를 빌드하고 실행하는 지역 스크립트입니다.
#
# 저장소 전체 검증은 ../../../scripts/quality와 ../../../scripts/context 아래 스크립트를
# 사용합니다. 이 스크립트는 그것들을 대체하지 않고, 한 패키지만 다룰 때의 지름길입니다.
#
# 내용은 다섯 패키지에서 완전히 같습니다. 패키지 이름과 컴포넌트 구성을 자기 위치와
# cabal 파일에서 읽어내므로 패키지마다 다르게 관리할 필요가 없습니다.

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_root="$(cd "$package_root/../.." && pwd)"
package="$(basename "$package_root")"
cabal_file="$package_root/$package.cabal"

usage() {
  cat <<USAGE
사용법: src/$package/scripts/run.sh [명령] [-- 인자...]

명령
  build   이 패키지와 이 패키지가 의존하는 패키지를 빌드합니다 (기본값)
  test    이 패키지의 테스트를 실행합니다
  run     이 패키지의 실행 파일을 실행합니다. 라이브러리 전용 패키지에는 없습니다
  repl    이 패키지 라이브러리의 GHCi 세션을 엽니다
  help    이 도움말을 출력합니다

예시
  src/$package/scripts/run.sh
  src/$package/scripts/run.sh test
  src/$package/scripts/run.sh run -- --help

의존 패키지는 cabal이 함께 빌드합니다. 예를 들어 cli를 빌드하면
store와 core도 함께 빌드됩니다. 허용된 의존 방향은
../../../ARCHITECTURE.md에 있습니다.
USAGE
}

executables() {
  awk '/^executable[[:space:]]+/ { print $2 }' "$cabal_file"
}

has_library() {
  awk '/^library[[:space:]]*$/ { found = 1 } END { exit !found }' "$cabal_file"
}

if [[ ! -f "$cabal_file" ]]; then
  printf '이 패키지의 cabal 파일을 찾을 수 없습니다: %s\n' "$cabal_file" >&2
  printf '디렉터리 이름과 cabal 파일 이름이 같아야 합니다.\n' >&2
  exit 1
fi

command_name="${1:-build}"
if [[ "$#" -gt 0 ]]; then
  shift
fi
# `run -- 인자` 와 `run 인자` 를 모두 허용합니다.
if [[ "${1:-}" == "--" ]]; then
  shift
fi

case "$command_name" in
  help | -h | --help)
    usage
    exit 0
    ;;
esac

if ! command -v cabal >/dev/null 2>&1; then
  printf 'cabal을 찾을 수 없습니다. GHC 9.10과 cabal 3.16 이상이 필요합니다.\n' >&2
  printf '설치 안내는 %s의 요구 사항을 참고하십시오.\n' "$repo_root/README.md" >&2
  exit 1
fi

# 다중 패키지 프로젝트이므로 cabal.project가 있는 저장소 루트에서 실행합니다.
cd "$repo_root"

case "$command_name" in
  build)
    cabal build "$package" "$@"
    ;;

  test)
    cabal test "$package" "$@"
    ;;

  run)
    executable="$(executables | awk 'NR == 1')"
    if [[ -z "$executable" ]]; then
      printf '%s에는 실행 파일이 없습니다. 라이브러리 전용 패키지입니다.\n' "$package" >&2
      printf '실행 가능한 표면은 cli와 api입니다.\n' >&2
      printf '이 패키지는 build 또는 test로 다루십시오.\n' >&2
      exit 1
    fi
    if [[ "$(executables | awk 'END { print NR }')" -gt 1 ]]; then
      printf '실행 파일이 여러 개여서 첫 번째를 실행합니다: %s\n' "$executable" >&2
    fi
    cabal run "$executable" -- "$@"
    ;;

  repl)
    if ! has_library; then
      printf '%s에는 라이브러리 컴포넌트가 없습니다.\n' "$package" >&2
      exit 1
    fi
    cabal repl "lib:$package" "$@"
    ;;

  *)
    printf '알 수 없는 명령입니다: %s\n\n' "$command_name" >&2
    usage >&2
    exit 2
    ;;
esac
