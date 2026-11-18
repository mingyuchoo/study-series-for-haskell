#!/usr/bin/env bash
set -euo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! command -v python3 >/dev/null 2>&1; then
  printf 'Python 3.11 or newer is required. See docs/RELEASE.md\n' >&2
  exit 1
fi
exec python3 "$script_directory/release/release.py" "$@"
