#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

if ! command -v stack >/dev/null 2>&1; then
  echo "error: stack is required but was not found in PATH" >&2
  exit 1
fi

RUN_ARGS=("$@")
if [ "$#" -eq 0 ]; then
  RUN_ARGS=(-o output.svg -w 400)
fi

echo "==> Building DiagramsDemo03"
stack build

echo "==> Testing DiagramsDemo03"
stack test

echo "==> Running DiagramsDemo03"
stack run -- "${RUN_ARGS[@]}"
