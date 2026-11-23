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

printf '\n[1/5] Formatting Haskell sources\n'
find app src test -type f -name '*.hs' -exec fourmolu --mode inplace \
  --config fourmolu.yaml --ghc-opt=-XImportQualifiedPost {} +

printf '\n[2/5] Linting Haskell sources\n'
hlint --no-exit-code app src test

printf '\n[3/5] Building HaskellGPT\n'
stack build

printf '\n[4/5] Testing HaskellGPT\n'
stack test

printf '\n[5/5] Running HaskellGPT\n'
exec stack run HaskellGPT-exe
