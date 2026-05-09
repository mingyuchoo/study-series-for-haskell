#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
MAKE_BIN="${MAKE:-make}"

cd "${PROJECT_ROOT}"

usage() {
  cat <<'EOF'
Usage: scripts/run.sh [all|build|test|run|help]

Runs project tasks through the Makefile.

Commands:
  all     Build, test, then run the application (default)
  build   Build the executable
  test    Run the test suite
  run     Run the application
  help    Show this help
EOF
}

run_make() {
  local target=$1
  printf '\n==> make %s\n' "${target}"
  "${MAKE_BIN}" "${target}"
}

command="${1:-all}"

case "${command}" in
  all)
    run_make build
    run_make test
    run_make run
    ;;
  build | test | run)
    run_make "${command}"
    ;;
  help | -h | --help)
    usage
    ;;
  *)
    printf 'Unknown command: %s\n\n' "${command}" >&2
    usage >&2
    exit 2
    ;;
esac
