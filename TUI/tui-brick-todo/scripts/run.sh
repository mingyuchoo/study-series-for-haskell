#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$project_root"

source_paths=(app src test Setup.hs)

for tool in stack fourmolu hlint; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Required tool not found: %s\n' "$tool" >&2
    printf 'Install Stack and run: stack install fourmolu hlint\n' >&2
    exit 1
  fi
done

run_step() {
  local label="$1"
  shift
  printf '\n==> %s\n' "$label"
  "$@"
}

run_step 'Formatting' find "${source_paths[@]}" -type f -name '*.hs' \
  -exec fourmolu --mode inplace {} +
run_step 'Linting' hlint "${source_paths[@]}"
run_step 'Building' stack build --test --no-run-tests
run_step 'Testing' stack test
run_step 'Running' stack exec tto-exe -- "$@"
