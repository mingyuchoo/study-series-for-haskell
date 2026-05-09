#!/bin/bash

echo "Formatting Haskell files..."

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
      echo "Processing $file"
      
      # Check for <| operator in test files
      if [[ "$dir" == "test" && $(grep -q "<|" "$file"; echo $?) -eq 0 ]]; then
        echo "Skipping $file (contains <| operator)"
      else
        stylish-haskell -i "$file" || echo "Failed to format $file"
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
    echo "Processing $file"
    stylish-haskell -i "$file" || echo "Failed to format $file"
  done
fi

echo "Formatting complete"
