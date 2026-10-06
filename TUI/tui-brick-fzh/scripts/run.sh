#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

format_directory() {
  local dir="$1"
  local directory_name="$2"

  if [ ! -d "$dir" ]; then
    echo "Directory $directory_name does not exist, skipping..."
    return
  fi

  if [ -z "$(find "$dir" -name '*.hs' -print -quit 2>/dev/null)" ]; then
    echo "No Haskell files found in $directory_name, skipping..."
    return
  fi

  while IFS= read -r -d '' file; do
    echo "Processing $file"

    if [ "$directory_name" = "test" ] && grep -q "<|" "$file"; then
      echo "Skipping $file (contains <| operator)"
    else
      stylish-haskell -i "$file" || echo "Failed to format $file"
    fi
  done < <(find "$dir" -type f -name '*.hs' -print0)
}

format_haskell_files() {
  echo "Formatting Haskell files..."

  format_directory "$ROOT_DIR/src" "src"
  format_directory "$ROOT_DIR/app" "app"
  format_directory "$ROOT_DIR/test" "test"

  while IFS= read -r -d '' file; do
    echo "Processing $file"
    stylish-haskell -i "$file" || echo "Failed to format $file"
  done < <(find "$ROOT_DIR" -maxdepth 1 -type f -name '*.hs' -print0)

  echo "Formatting complete"
}

format_haskell_files

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
