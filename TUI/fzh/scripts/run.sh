#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: scripts/run.sh <command>

Commands:
  build   Build the project with Makefile
  test    Run tests with Makefile
  run     Build and run the app with Makefile
  all     Clean, setup, build, test, and run with Makefile
  clean   Clean build artifacts with Makefile
EOF
}

command="${1:-run}"

case "$command" in
  build|test|run|all|clean)
    cd "$ROOT_DIR"
    exec make "$command"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "Unknown command: $command" >&2
    usage >&2
    exit 2
    ;;
esac
