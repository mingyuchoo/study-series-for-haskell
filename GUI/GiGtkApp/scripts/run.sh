#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s [all|format|lint|build|test|run]\n' "${0##*/}"
  printf 'Default: format, lint, build, test, then run.\n'
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required command not found in PATH: %s\n' "$1" >&2
    exit 127
  fi
}

format_sources() {
  printf '\n==> Formatting Haskell sources\n'
  fourmolu --mode inplace --config fourmolu.yaml "${source_files[@]}"
  stylish-haskell -c .stylish-haskell.yaml -i "${source_files[@]}"
}

lint_sources() {
  printf '\n==> Linting Haskell sources\n'
  hlint "${source_files[@]}"
}

build_app() {
  printf '\n==> Building GiGtkApp\n'
  "$stack_command" build --fast
}

test_app() {
  printf '\n==> Testing GiGtkApp\n'
  "$stack_command" test --fast
}

run_app() {
  printf '\n==> Running GiGtkApp-exe\n'
  exec "$stack_command" run GiGtkApp-exe
}

action="${1-all}"
if (( $# > 1 )); then
  usage >&2
  exit 2
fi
case "$action" in
  -h|--help|help) usage; exit 0 ;;
  all|format|lint|build|test|run) ;;
  *) usage >&2; exit 2 ;;
esac

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
stack_command="${STACK:-stack}"

case "$action" in
  all|format|lint)
    shopt -s nullglob
    source_files=(./*.hs)
    while IFS= read -r -d '' source_file; do
      source_files+=("$source_file")
    done < <(find app src test -type f -name '*.hs' -print0)
    ;;
esac

case "$action" in
  all|format) require_command fourmolu; require_command stylish-haskell ;;
esac
case "$action" in
  all|lint) require_command hlint ;;
esac
case "$action" in
  all|build|test|run)
    require_command "$stack_command"
    require_command pkg-config
    if ! pkg-config --exists --print-errors gobject-introspection-1.0 gtk4; then
      printf 'GTK 4 and GObject Introspection development packages are required.\n' >&2
      exit 1
    fi
    ;;
esac

case "$action" in
  all) format_sources; lint_sources; build_app; test_app; run_app ;;
  format) format_sources ;;
  lint) lint_sources ;;
  build) build_app ;;
  test) test_app ;;
  run) run_app ;;
esac
