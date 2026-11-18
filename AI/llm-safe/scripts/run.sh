#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$project_root"

for tool in stack fourmolu hlint; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Required tool not found: %s\nInstall Stack and run: stack install fourmolu hlint\n' "$tool" >&2
    exit 127
  fi
done

printf '\n[1/5] Formatting Haskell sources\n'
find src app test -type f \( -name '*.hs' -o -name '*.lhs' \) -print0 |
  while IFS= read -r -d '' source_file; do
    fourmolu --mode inplace --config fourmolu.yaml "$source_file"
  done

printf '\n[2/5] Linting Haskell sources\n'
hlint --extension=ImportQualifiedPost src app test

printf '\n[3/5] Building\n'
stack build

printf '\n[4/5] Running tests\n'
stack test

printf '\n[5/5] Starting llm-safe-exe\n'
exec stack exec -- llm-safe-exe "$@"
