#!/bin/bash

echo "Formatting Haskell files..."

# Resolve script directory so config files are found regardless of CWD
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FOURMOLU_CONFIG="$SCRIPT_DIR/fourmolu.yaml"
STYLISH_CONFIG="$SCRIPT_DIR/.stylish-haskell.yaml"

# Format a single file: fourmolu first (overall layout), then
# stylish-haskell (imports, pragmas, module header).
format_file() {
  local file=$1
  echo "Processing $file"

  if command -v fourmolu >/dev/null 2>&1; then
    fourmolu --mode inplace --config "$FOURMOLU_CONFIG" "$file" \
      || echo "fourmolu failed to format $file"
  else
    echo "fourmolu not found, skipping fourmolu for $file"
  fi

  if command -v stylish-haskell >/dev/null 2>&1; then
    stylish-haskell -c "$STYLISH_CONFIG" -i "$file" \
      || echo "stylish-haskell failed to format $file"
  else
    echo "stylish-haskell not found, skipping stylish-haskell for $file"
  fi
}

# Function to format files in a directory
format_directory() {
  local dir=$1

  # Check if directory exists
  if [ ! -d "$dir" ]; then
    echo "Directory $dir does not exist, skipping..."
    return
  fi

  # Check if there are any .hs files in the directory
  if [ -z "$(find "$dir" -name '*.hs' 2>/dev/null)" ]; then
    echo "No Haskell files found in $dir, skipping..."
    return
  fi

  # Process each .hs file in the directory
  find "$dir" -name "*.hs" | while read -r file; do
    if [ -f "$file" ]; then
      # Check for <| operator in test files
      if [[ "$dir" == "test" && $(grep -q "<|" "$file"; echo $?) -eq 0 ]]; then
        echo "Skipping $file (contains <| operator)"
      else
        format_file "$file"
      fi
    fi
  done
}

# Format files in common Haskell project directories
format_directory "src"
format_directory "app"
format_directory "test"

# Format any other .hs files in the current directory
if [ -n "$(find . -maxdepth 1 -name '*.hs' 2>/dev/null)" ]; then
  echo "Processing Haskell files in current directory"
  find . -maxdepth 1 -name "*.hs" | while read -r file; do
    format_file "$file"
  done
fi

echo "Formatting complete"
