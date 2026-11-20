#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

if (( $# == 0 )); then
    set -- --help
fi

printf '%s\n' '==> Format'
find packages apps -name '*.hs' -exec fourmolu --mode inplace {} +

printf '%s\n' '==> Lint'
hlint packages apps

printf '%s\n' '==> Build'
cabal build all

printf '%s\n' '==> Test'
cabal test all

printf '%s\n' '==> Run'
exec cabal run -v0 git-puller -- "$@"
