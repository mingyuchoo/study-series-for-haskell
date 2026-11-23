#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

for tool in fourmolu stylish-haskell hlint stack; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$tool" >&2
    exit 127
  fi
done

printf 'Formatting Haskell sources...\n'
find Setup.hs src app test -type f -name '*.hs' -exec bash -e -c '
  for file do
    fourmolu --mode inplace --config fourmolu.yaml "$file"
    stylish-haskell -c .stylish-haskell.yaml -i "$file"
  done
' bash {} +

printf 'Linting Haskell sources...\n'
hlint --no-exit-code Setup.hs src app test

printf 'Building...\n'
stack build

printf 'Running tests against local PostgreSQL and Redis (the tests flush Redis)...\n'
stack test --rerun-tests

printf 'Starting the server...\n'
exec stack exec run-server -- "$@"
