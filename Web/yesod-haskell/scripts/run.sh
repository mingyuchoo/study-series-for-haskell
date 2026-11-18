#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$project_root"

if command -v cabal >/dev/null 2>&1; then
  cabal_install_dir="$(cabal path --installdir)"
  export PATH="$PATH:$cabal_install_dir"
fi

for tool in ghc cabal fourmolu hlint; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Required tool not found in PATH: %s\nSee README.md for setup instructions.\n' "$tool" >&2
    exit 1
  fi
done

printf '\n[1/5] Formatting Haskell sources\n'
find src app test -type f \( -name '*.hs' -o -name '*.lhs' \) -print0 |
  while IFS= read -r -d '' file; do
    fourmolu --mode inplace --config fourmolu.yaml "$file"
  done

printf '\n[2/5] Linting Haskell sources\n'
hlint src app test

printf '\n[3/5] Building all components\n'
cabal build all --enable-tests

printf '\n[4/5] Running tests\n'
cabal test all --test-show-details=streaming

printf '\n[5/5] Starting server at http://localhost:3000 (Ctrl+C to stop)\n'
exec cabal run yesod-haskell -- "$@"
