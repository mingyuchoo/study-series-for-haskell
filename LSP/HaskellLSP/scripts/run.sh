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

source_files=(./*.hs)
while IFS= read -r -d '' source_file; do
  source_files+=("$source_file")
done < <(find app src test -type f -name '*.hs' -print0)

printf '\n[1/5] Formatting Haskell sources\n' >&2
fourmolu --mode inplace --config fourmolu.yaml "${source_files[@]}" >&2

printf '\n[2/5] Linting Haskell sources\n' >&2
hlint --no-exit-code "${source_files[@]}" >&2

printf '\n[3/5] Building HaskellLSP\n' >&2
stack build --fast >&2

printf '\n[4/5] Testing HaskellLSP\n' >&2
stack test --fast >&2

printf '\n[5/5] Running HaskellLSP\n' >&2
exec stack exec HaskellLSP-exe -- "$@"
