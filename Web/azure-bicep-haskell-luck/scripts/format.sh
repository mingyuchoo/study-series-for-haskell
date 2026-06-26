#!/bin/bash
#
# Format the whole repository:
#   * backend/  — Haskell, with BOTH formatters in order:
#       1. fourmolu        — overall layout (indentation, wrapping, leading commas)  [fourmolu.yaml]
#       2. stylish-haskell — import tidy-up and ::/= alignment                       [.stylish-haskell.yaml]
#     stylish runs LAST on purpose: this codebase keeps stylish's `::`/`=` alignment,
#     which fourmolu would otherwise flatten. fourmolu -> stylish reproduces the
#     committed style and is stable across repeated runs.
#   * frontend/ — TypeScript/TSX/CSS/JSON, with Prettier.
#
# Runs from anywhere (paths are resolved relative to this script). Each language
# section is independent: if one language's tools are missing it is skipped with a
# warning, so the other language still gets formatted.

set -uo pipefail

# Resolve repo root (scripts/ lives directly under it).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

backend_status="skipped"
frontend_status="skipped"

# ---------------------------------------------------------------------------
# Backend — Haskell (fourmolu -> stylish-haskell)
# ---------------------------------------------------------------------------

# Format a single Haskell file with both tools.
format_haskell_file() {
  local file=$1
  echo "  $file"
  fourmolu -i "$file" || echo "    fourmolu failed on $file"
  # stylish-haskell historically mis-parses the '<|' operator; skip it for such files.
  if grep -q "<|" "$file"; then
    echo "    skipping stylish-haskell ('<|' present)"
  else
    stylish-haskell -i "$file" || echo "    stylish-haskell failed on $file"
  fi
}

format_backend() {
  local base="$ROOT/backend"

  if [ ! -d "$base" ]; then
    echo "backend/ not found, skipping Haskell formatting."
    return
  fi

  # Both Haskell formatters must be available.
  local missing=0
  for tool in fourmolu stylish-haskell; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "Warning: '$tool' not found in PATH. Install it (e.g. 'cabal install $tool' or via ghcup)." >&2
      missing=1
    fi
  done
  if [ "$missing" -eq 1 ]; then
    echo "Skipping backend: required Haskell formatter(s) missing." >&2
    return
  fi

  # Collect every .hs file under the backend package (src/app/test + loose files).
  local files
  files="$(find "$base" -type f -name '*.hs' -not -path '*/dist-newstyle/*')"
  if [ -z "$files" ]; then
    echo "No Haskell files found under backend/, skipping..."
    return
  fi

  echo "Formatting backend/ Haskell (fourmolu -> stylish-haskell)..."
  while IFS= read -r file; do
    [ -f "$file" ] && format_haskell_file "$file"
  done <<< "$files"
  backend_status="done"
}

# ---------------------------------------------------------------------------
# Frontend — TypeScript/TSX/CSS/JSON (Prettier)
# ---------------------------------------------------------------------------

# Resolve a runnable Prettier command (prefer locally installed, else npx).
resolve_prettier() {
  if [ -x "$ROOT/frontend/node_modules/.bin/prettier" ]; then
    echo "$ROOT/frontend/node_modules/.bin/prettier"
  elif [ -x "$ROOT/node_modules/.bin/prettier" ]; then
    echo "$ROOT/node_modules/.bin/prettier"
  elif command -v prettier >/dev/null 2>&1; then
    echo "prettier"
  elif command -v npx >/dev/null 2>&1; then
    echo "npx --yes prettier"
  else
    echo ""
  fi
}

format_frontend() {
  local base="$ROOT/frontend"

  if [ ! -d "$base" ]; then
    echo "frontend/ not found, skipping Prettier formatting."
    return
  fi

  local prettier
  prettier="$(resolve_prettier)"
  if [ -z "$prettier" ]; then
    echo "Warning: Prettier not found and 'npx' unavailable. Skipping frontend." >&2
    echo "  Install with: (cd frontend && npm i -D prettier)" >&2
    return
  fi

  # src is always present; add root config files only if they exist (avoids errors).
  local targets=( "frontend/src/**/*.{ts,tsx,js,jsx,css,json}" )
  local f
  for f in index.html vite.config.ts package.json tsconfig.json; do
    [ -f "$base/$f" ] && targets+=( "frontend/$f" )
  done

  echo "Formatting frontend/ with Prettier ($prettier)..."
  # Run from repo root so the globs resolve; print-width 100 matches the existing style.
  ( cd "$ROOT" && $prettier --write --print-width 100 --log-level warn "${targets[@]}" )
  if [ "$?" -eq 0 ]; then
    frontend_status="done"
  else
    echo "Warning: Prettier reported errors." >&2
    frontend_status="errors"
  fi
}

# ---------------------------------------------------------------------------

format_backend
echo
format_frontend

echo
echo "Formatting complete (backend: $backend_status, frontend: $frontend_status)"
