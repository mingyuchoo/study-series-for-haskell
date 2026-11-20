#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage: scripts/run.sh [all|check|format|lint|build|test|run|help] [-- APP_ARGS...]

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
Arguments after -- are passed to the GUI for all/run only.
Examples: scripts/run.sh; scripts/run.sh check; scripts/run.sh run -- +RTS -N2 -RTS
EOF
}

command_name="${1:-all}"
if (( $# > 0 )); then shift; fi
case "$command_name" in
  help|-h|--help) usage; exit 0 ;;
  all|check|format|lint|build|test|run) ;;
  *) printf 'error: unknown command: %s\n' "$command_name" >&2; usage >&2; exit 2 ;;
esac
if [[ "${1:-}" == -- ]]; then shift; fi
if (( $# > 0 )) && [[ "$command_name" != all && "$command_name" != run ]]; then
  printf 'error: app arguments are only supported by all/run.\n' >&2
  exit 2
fi

required_tools=()
case "$command_name" in
  all|check) required_tools=(fourmolu hlint stack) ;;
  format) required_tools=(fourmolu) ;;
  lint) required_tools=(hlint) ;;
  *) required_tools=(stack) ;;
esac
missing=0
for tool in "${required_tools[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'error: required command not found on PATH: %s\n' "$tool" >&2
    missing=1
  fi
done
if (( missing )); then usage >&2; exit 127; fi

# Include project sources, never .stack-work, dist-newstyle, or external caches.
sources=()
if [[ "$command_name" == all || "$command_name" == check || "$command_name" == format || "$command_name" == lint ]]; then
  source_dirs=()
  for dir in src app test tests; do
    if [[ -d "$dir" ]]; then source_dirs+=("$dir"); fi
  done
  while IFS= read -r -d '' file; do sources+=("$file"); done < <(
    find . -maxdepth 1 -type f \( -name '*.hs' -o -name '*.lhs' \) -print0
    if (( ${#source_dirs[@]} )); then
      find "${source_dirs[@]}" -type f \( -name '*.hs' -o -name '*.lhs' \) -print0
    fi
  )
  if (( ${#sources[@]} == 0 )); then
    printf 'error: no Haskell source files found.\n' >&2
    exit 1
  fi
fi

stage=setup
trap 'status=$?; printf "error: %s failed (exit %s).\n" "$stage" "$status" >&2; exit "$status"' ERR

run_stage() {
  stage="$1"
  shift
  printf '\n==> %s\n' "$stage"
  case "$stage" in
    format) fourmolu --mode inplace --ghc-opt=-XImportQualifiedPost --ghc-opt=-XOverloadedStrings "${sources[@]}" ;;
    lint) hlint -XImportQualifiedPost -XOverloadedStrings "${sources[@]}" ;;
    build) stack build ;;
    test)
      if ! LC_ALL=C grep -Eq '^[[:space:]]*test-suite[[:space:]]' MonomerTodo.cabal; then
        printf 'Note: no test suite is registered; stack test will still be invoked.\n'
      fi
      stack test
      ;;
    run) stack run MonomerTodo:exe:app -- "$@" ;;
  esac
}

case "$command_name" in
  all|check)
    for step in format lint build test; do run_stage "$step"; done
    if [[ "$command_name" == all ]]; then run_stage run "$@"; fi
    ;;
  *) run_stage "$command_name" "$@" ;;
esac
