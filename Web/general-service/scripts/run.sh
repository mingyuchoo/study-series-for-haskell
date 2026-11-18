#!/usr/bin/env bash

set -euo pipefail

case "${1:-}" in
  '') check_only=false ;;
  --check-only) check_only=true ;;
  *) printf 'Usage: %s [--check-only]\n' "$0" >&2; exit 2 ;;
esac

if (( $# > 1 )); then
  printf 'Usage: %s [--check-only]\n' "$0" >&2
  exit 2
fi

cd "$(dirname "${BASH_SOURCE[0]}")/.."

for command_name in fourmolu hlint elm-format elm stack npm npx; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$command_name" >&2
    exit 1
  fi
done

printf '\nFormatting Haskell and Elm...\n'
fourmolu --mode inplace --config fourmolu.yaml Setup.hs app src test
elm-format --yes web/src web/tests

printf '\nLinting Haskell and checking Elm formatting...\n'
hlint --no-exit-code Setup.hs app src test
elm-format --validate web/src web/tests

printf '\nBuilding Haskell and Elm...\n'
stack build
(
  cd web
  elm make src/Main.elm --output=elm.js
)

printf '\nTesting Haskell and Elm...\n'
stack test
(
  cd web
  npm ci
  npx --no-install elm-test
)

if [[ "$check_only" == false ]]; then
  printf '\nStarting GeneralService...\n'
  exec stack run
fi
