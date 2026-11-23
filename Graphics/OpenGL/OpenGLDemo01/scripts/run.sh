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

shopt -s nullglob
source_files=(./*.hs)
while IFS= read -r -d '' source_file; do
  source_files+=("$source_file")
done < <(find app src test -type f -name '*.hs' -print0)

printf '\n[1/5] Formatting Haskell sources\n'
fourmolu --mode inplace --config fourmolu.yaml "${source_files[@]}"

printf '\n[2/5] Linting Haskell sources\n'
hlint "${source_files[@]}"

printf '\n[3/5] Building OpenGLDemo01\n'
stack build

printf '\n[4/5] Testing OpenGLDemo01\n'
stack test

printf '\n[5/5] Running OpenGLDemo01\n'
exec stack run OpenGLDemo01-exe -- "$@"
