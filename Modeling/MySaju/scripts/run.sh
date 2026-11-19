#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$project_root"

for tool in stack fourmolu hlint; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Required tool not found in PATH: %s\nInstall Stack, then run: stack install fourmolu hlint\n' "$tool" >&2
    exit 127
  fi
done

source_files=(Setup.hs)
while IFS= read -r -d '' source_file; do
  source_files+=("$source_file")
done < <(find src app test -type f -name '*.hs' -print0)

run_stage() {
  local stage_name="$1"
  shift
  printf '\n==> %s\n' "$stage_name"
  "$@"
}

run_stage 'Formatting' fourmolu --mode inplace "${source_files[@]}"
run_stage 'Linting' hlint "${source_files[@]}"
run_stage 'Building' stack build
run_stage 'Testing' stack test
run_stage 'Running' stack exec MySaju-exe -- "$@"
