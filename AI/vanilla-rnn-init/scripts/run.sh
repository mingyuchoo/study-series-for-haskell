#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$project_root"

for tool in stack stylish-haskell hlint; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Required tool not found: %s\nInstall Stack and run: stack install stylish-haskell hlint\n' "$tool" >&2
    exit 127
  fi
done

printf '\n[1/5] Formatting Haskell sources\n'
find Setup.hs src app test -type f \( -name '*.hs' -o -name '*.lhs' \) -print0 |
  while IFS= read -r -d '' source_file; do
    stylish-haskell --config .stylish-haskell.yaml --inplace "$source_file"
  done

printf '\n[2/5] Linting Haskell sources\n'
hlint Setup.hs src app test

printf '\n[3/5] Building\n'
stack build

printf '\n[4/5] Running tests\n'
stack test

printf '\n[5/5] Starting vanilla-rnn-init-exe\n'
exec stack exec -- vanilla-rnn-init-exe "$@"
