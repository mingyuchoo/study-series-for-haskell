#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

for tool in fourmolu hlint stack; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Required tool is missing from PATH: %s\n' "$tool" >&2
        exit 1
    fi
done

printf '%s\n' 'Formatting Haskell sources'
fourmolu --mode inplace app src test integration

printf '%s\n' 'Linting Haskell sources'
hlint --no-exit-code app src test integration

printf '%s\n' 'Building application and tests'
stack build --test --no-run-tests

printf '%s\n' 'Running tests'
stack test

printf '%s\n' 'Starting TodoList'
exec stack run todo-list
