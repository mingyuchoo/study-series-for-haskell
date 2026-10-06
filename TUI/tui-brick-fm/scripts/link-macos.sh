#!/bin/bash
set -euo pipefail

# GHC 9.10's RTS passes both of these options. dynamic_lookup already
# permits undefined symbols, so the individual -U exemption is redundant.
# Also pass the math library only once when GHC repeats -lm.
# Keep every other linker argument and diagnostic intact.
dynamic_lookup=false
previous=''
for argument in "$@"; do
  if [[ "$argument" == '-Wl,-undefined,dynamic_lookup' ]] ||
     [[ "$previous" == '-undefined' && "$argument" == 'dynamic_lookup' ]]; then
    dynamic_lookup=true
  fi
  previous="$argument"
done

temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/hfm-link.XXXXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT

arguments=()
math_library_seen=false
for argument in "$@"; do
  if [[ "$dynamic_lookup" == true &&
        "$argument" == '-Wl,-U,___darwin_check_fd_set_overflow' ]]; then
    continue
  fi
  if [[ "$argument" == '-lm' ]]; then
    if [[ "$math_library_seen" == true ]]; then
      continue
    fi
    math_library_seen=true
  fi
  if [[ "$argument" == @* ]]; then
    # GHC normally puts its arguments in a response file, one quoted
    # argument per line. Preserve quoting rather than evaluating its contents.
    response_file=${argument#@}
    filtered_file="$temporary_directory/${#arguments[@]}.rsp"
    awk '
      {
        key = $0
        sub(/^"/, "", key)
        sub(/"$/, "", key)
      }
      NR == FNR {
        if (key == "-Wl,-undefined,dynamic_lookup") dynamic_lookup = 1
        next
      }
      dynamic_lookup && key == "-Wl,-U,___darwin_check_fd_set_overflow" { next }
      key == "-lm" && math_library_seen++ { next }
      { print }
    ' "$response_file" "$response_file" > "$filtered_file"
    arguments+=("@$filtered_file")
  else
    arguments+=("$argument")
  fi
done

/usr/bin/cc "${arguments[@]}"
