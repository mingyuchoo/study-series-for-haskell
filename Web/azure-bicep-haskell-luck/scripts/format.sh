#!/bin/bash
#
# Format all Haskell sources with BOTH formatters, in order:
#   1. fourmolu       — overall layout (indentation, wrapping, leading commas)   [fourmolu.yaml]
#   2. stylish-haskell — import tidy-up and ::/= alignment                        [.stylish-haskell.yaml]
#
# stylish runs LAST on purpose: this codebase keeps stylish's `::`/`=` alignment,
# which fourmolu would otherwise flatten. Applying fourmolu then stylish reproduces
# the committed style and is stable across repeated runs.

echo "Formatting Haskell files (fourmolu -> stylish-haskell)..."

# Both formatters must be available.
missing=0
for tool in fourmolu stylish-haskell; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Error: '$tool' not found in PATH. Install it (e.g. 'cabal install $tool' or via ghcup)." >&2
    missing=1
  fi
done
if [ "$missing" -eq 1 ]; then
  echo "Aborting: required formatter(s) missing." >&2
  exit 1
fi

# Format a single file with both tools.
format_file() {
  local file=$1
  echo "Processing $file"
  fourmolu -i "$file" || echo "  fourmolu failed on $file"
  # stylish-haskell historically mis-parses the '<|' operator; skip it for such files.
  if grep -q "<|" "$file"; then
    echo "  Skipping stylish-haskell for $file (contains '<|')"
  else
    stylish-haskell -i "$file" || echo "  stylish-haskell failed on $file"
  fi
}

# Format every .hs file under a directory.
format_directory() {
  local dir=$1

  if [ ! -d "$dir" ]; then
    echo "Directory $dir does not exist, skipping..."
    return
  fi

  if [ -z "$(find "$dir" -name '*.hs' 2>/dev/null)" ]; then
    echo "No Haskell files found in $dir, skipping..."
    return
  fi

  find "$dir" -name "*.hs" | while read -r file; do
    [ -f "$file" ] && format_file "$file"
  done
}

# Format files in common Haskell project directories.
format_directory "src"
format_directory "app"
format_directory "test"

# Format any other .hs files in the current directory.
if [ -n "$(find . -maxdepth 1 -name '*.hs' 2>/dev/null)" ]; then
  echo "Processing Haskell files in current directory"
  find . -maxdepth 1 -name "*.hs" | while read -r file; do
    format_file "$file"
  done
fi

echo "Formatting complete"
