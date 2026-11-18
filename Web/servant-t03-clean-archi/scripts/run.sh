#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

for tool in fourmolu hlint stack npm; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Required command not found on PATH: %s\n' "$tool" >&2
    exit 127
  fi
done

printf '%s\n' 'Formatting Haskell sources'
find Setup.hs app src test -type f -name '*.hs' \
  -exec fourmolu --mode inplace --config fourmolu.yaml --ghc-opt=-XGHC2024 {} +

printf '%s\n' 'Linting Haskell sources'
hlint --ignore-suggestions Setup.hs app src test

printf '%s\n' 'Building Elm frontend'
npm ci
npm run build

printf '%s\n' 'Building'
stack build --fast --test --no-run-tests

printf '%s\n' 'Running tests'
stack test --fast

printf '%s\n' 'Starting server on port 8000'
exec stack exec servant-t03-clean-archi-exe
