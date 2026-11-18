#!/usr/bin/env bash

set -euo pipefail

show_help() {
  printf '%s\n' \
    'Usage: scripts/run.sh [--skip-run] [--help]' \
    '' \
    'Format, lint, build, test, and run the application.' \
    '  --skip-run  Stop after tests without starting the server.' \
    '  --help      Show this help.' \
    '' \
    'Required commands: stack, fourmolu, hlint'
}

skip_run=false

for argument in "$@"; do
  case "$argument" in
    --skip-run) skip_run=true ;;
    -h | --help)
      show_help
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$argument" >&2
      show_help >&2
      exit 2
      ;;
  esac
done

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$project_root"

for required_command in stack fourmolu hlint; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$required_command" >&2
    printf 'Install Stack, then install development tools with: stack install fourmolu hlint\n' >&2
    exit 127
  fi
done

shopt -s nullglob
source_files=(*.hs)

while IFS= read -r -d '' source_file; do
  source_files+=("$source_file")
done < <(find src app test -type f -name '*.hs' -print0)

printf '\n[1/5] Formatting Haskell sources\n'
for source_file in "${source_files[@]}"; do
  fourmolu --mode inplace --config "$project_root/fourmolu.yaml" "$source_file"
done

printf '\n[2/5] Linting Haskell sources\n'
hlint --language=GHC2024 "${source_files[@]}"

printf '\n[3/5] Building application and tests\n'
stack build --test --no-run-tests

printf '\n[4/5] Running tests\n'
stack test

if [[ "$skip_run" == true ]]; then
  printf '\nChecks completed. Server startup skipped.\n'
  exit 0
fi

printf '\n[5/5] Starting server at http://localhost:8000 (Ctrl+C to stop)\n'
exec stack exec warp-t03-clean-archi-exe
