#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$project_root"

for tool in fourmolu hlint stack; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Required command not found in PATH: %s\n' "$tool" >&2
    exit 127
  fi
done

source_dirs=(app src)
if [[ -d test ]]; then
  source_dirs+=(test)
fi

printf '\n[1/5] Formatting Haskell sources\n'
find "${source_dirs[@]}" -type f -name '*.hs' \
  -exec fourmolu --mode inplace --config fourmolu.yaml {} +

printf '\n[2/5] Linting Haskell sources\n'
hlint --no-exit-code "${source_dirs[@]}"

printf '\n[3/5] Building project\n'
stack build

printf '\n[4/5] Testing project\n'
stack test

printf '\n[5/5] Running application\n'
exec stack run azure-openai-haskell-init-exe -- "$@"
