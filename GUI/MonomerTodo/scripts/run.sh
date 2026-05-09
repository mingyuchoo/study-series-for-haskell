#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: scripts/run.sh [build|test|run|all|help]

Commands:
  build   Build the application through Makefile
  test    Run tests through Makefile
  run     Run the application through Makefile
  all     Build and test through Makefile
  help    Show this help
EOF
}

command_name="${1:-run}"
shift || true

case "${command_name}" in
  build | test | run | all)
    exec make -C "${ROOT_DIR}" "${command_name}" "$@"
    ;;
  help | -h | --help)
    usage
    ;;
  *)
    echo "error: unknown command: ${command_name}" >&2
    usage >&2
    exit 1
    ;;
esac
