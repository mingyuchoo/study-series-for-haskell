#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
COMMAND="${1:-run}"

usage() {
  cat <<'USAGE'
Usage: scripts/run.sh [build|test|run|all|clean|help] [LEFT_DIR] [RIGHT_DIR]

  build  Build fzh-exe
  test   Run the test suite
  run    Build and open the file manager (default)
  all    Build, test, then open the file manager
  clean  Remove Stack build artifacts

Directory arguments are accepted by run and all. A controlling terminal is required.
USAGE
}

case "$COMMAND" in
  -h|--help|help)
    usage
    exit 0
    ;;
  build|test|run|all|clean)
    if [ "$#" -gt 0 ]; then shift; fi
    ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    usage >&2
    exit 2
    ;;
esac

if [ "$COMMAND" != run ] && [ "$COMMAND" != all ] && [ "$#" -gt 0 ]; then
  echo "Directory arguments are only accepted by run and all" >&2
  exit 2
fi
if [ "$#" -gt 2 ]; then
  echo "At most two starting directories are supported" >&2
  exit 2
fi

cd "$ROOT_DIR"
case "$COMMAND" in
  build) exec stack build ;;
  test) exec stack test ;;
  run) exec stack run -- "$@" ;;
  all)
    stack build
    stack test
    exec stack run -- "$@"
    ;;
  clean) exec stack clean ;;
esac
