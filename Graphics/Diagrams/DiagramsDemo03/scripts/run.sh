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

if [ "$#" -eq 0 ]; then
  set -- -o output.svg -w 400
fi

shopt -s nullglob
source_files=(./*.hs)
while IFS= read -r -d '' source_file; do
  source_files+=("$source_file")
done < <(find app src test -type f -name '*.hs' -print0)

printf '\n[1/5] Formatting Haskell sources\n'
fourmolu --mode inplace --config fourmolu.yaml "${source_files[@]}"

printf '\n[2/5] Linting Haskell sources\n'
hlint "${source_files[@]}"

printf '\n[3/5] Building DiagramsDemo03\n'
stack build

printf '\n[4/5] Testing DiagramsDemo03\n'
stack test

printf '\n[5/5] Running DiagramsDemo03\n'
exec stack run DiagramsDemo03-exe -- "$@"
