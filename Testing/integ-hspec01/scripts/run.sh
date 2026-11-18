#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$project_root"

for tool in stack fourmolu hlint; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Required command not found: %s. See README.md for setup.\n' "$tool" >&2
    exit 127
  fi
done

shopt -s nullglob
source_files=(./*.hs)
while IFS= read -r -d '' source_file; do
  source_files+=("$source_file")
done < <(find src app test -type f -name '*.hs' -print0)

printf '\n[1/5] Formatting Haskell sources\n'
fourmolu --mode inplace --config fourmolu.yaml "${source_files[@]}"

printf '\n[2/5] Linting Haskell sources\n'
hlint "${source_files[@]}"

printf '\n[3/5] Building\n'
stack build --fast

printf '\n[4/5] Testing\n'
stack test --fast

printf '\n[5/5] Running integ-hspec01-exe\n'
exec stack exec integ-hspec01-exe -- "$@"
