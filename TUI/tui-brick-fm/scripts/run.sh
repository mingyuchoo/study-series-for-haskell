#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
COMMAND="${1:-all}"

usage() {
  cat <<'USAGE'
Usage: scripts/run.sh [format|lint|build|test|run|all|clean|help] [LEFT_DIR] [RIGHT_DIR]

  format Format workspace Haskell sources with stylish-haskell
  lint   Check workspace Haskell sources with HLint on x86
  build  Build hfm
  test   Check architecture and run the test suite
  run    Build and open the file manager
  all    Format, lint, build, test, then open the file manager (default)
  clean  Remove Stack build artifacts

Directory arguments are accepted by run and all. A controlling terminal is required.
Required tools: stylish-haskell (format/all), Stack (build/test/run/clean/all),
and hlint (lint/all on x86).
USAGE
}

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required. Install it and add it to PATH." >&2
    exit 127
  fi
}

collect_sources() {
  local source_directory source_file source_file_list source_discovery_status=0
  local source_directories=()
  for source_directory in apps/*/app apps/*/src apps/*/test packages/*/src packages/*/test packages/*/app packages/*/pty; do
    if [ -d "$source_directory" ]; then
      source_directories+=("$source_directory")
    fi
  done
  if [ "${#source_directories[@]}" -eq 0 ]; then
    echo "No workspace source directories found" >&2
    exit 1
  fi
  source_file_list="$(mktemp)"
  find "${source_directories[@]}" -type f -name '*.hs' -print0 > "$source_file_list" || source_discovery_status=$?
  SOURCE_FILES=()
  while IFS= read -r -d '' source_file; do
    SOURCE_FILES+=("$source_file")
  done < "$source_file_list"
  rm -f -- "$source_file_list"
  if [ "$source_discovery_status" -ne 0 ]; then
    return "$source_discovery_status"
  fi
  if [ "${#SOURCE_FILES[@]}" -eq 0 ]; then
    echo "No workspace Haskell sources found" >&2
    exit 1
  fi
}

case "$COMMAND" in
  -h|--help|help)
    usage
    exit 0
    ;;
  format|lint|build|test|run|all|clean)
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

STARTING_DIRECTORIES=()
for directory in "$@"; do
  if [ ! -d "$directory" ]; then
    echo "Not a filesystem directory: $directory" >&2
    exit 2
  fi
  STARTING_DIRECTORIES+=("$(cd -- "$directory" && pwd -P)")
done

RUN_HLINT=false
if [ "$COMMAND" = lint ] || [ "$COMMAND" = all ]; then
  CPU_ARCH="$(uname -m)"
  case "$CPU_ARCH" in
    x86|x86_64|amd64|i[3-6]86) RUN_HLINT=true ;;
  esac
fi

case "$COMMAND" in
  format) require_tool stylish-haskell ;;
  lint)
    if [ "$RUN_HLINT" = false ]; then
      echo "Skipping HLint on $CPU_ARCH."
      exit 0
    fi
    require_tool hlint
    ;;
  build|run|clean) require_tool stack ;;
  test) require_tool stack ;;
  all)
    require_tool stylish-haskell
    if [ "$RUN_HLINT" = true ]; then
      require_tool hlint
    fi
    require_tool stack
    ;;
esac

cd "$ROOT_DIR"
if [ "$COMMAND" = format ] || [ "$COMMAND" = lint ] || [ "$COMMAND" = all ]; then
  collect_sources
fi

if [ "$COMMAND" = format ] || [ "$COMMAND" = all ]; then
  stylish-haskell --config .stylish-haskell.yaml -i "${SOURCE_FILES[@]}"
fi
if [ "$RUN_HLINT" = true ]; then
  hlint "${SOURCE_FILES[@]}"
fi
if [ "$COMMAND" = build ] || [ "$COMMAND" = all ]; then
  stack build
fi
if [ "$COMMAND" = test ] || [ "$COMMAND" = all ]; then
  stack run hfm-check-architecture
  stack test
fi
case "$COMMAND" in
  run|all)
    if [ "$#" -gt 0 ]; then
      exec stack run hfm -- "${STARTING_DIRECTORIES[@]}"
    fi
    exec stack run hfm --
    ;;
  clean) exec stack clean ;;
esac
