#!/usr/bin/env bash
#
# Build, test, and run the GiGtkApp GTK application.
#
# Usage:
#   scripts/run.sh            Build, test, then run (default)
#   scripts/run.sh build      Build the library and executable only
#   scripts/run.sh test       Run the test suite only
#   scripts/run.sh run        Run the application only
#   scripts/run.sh all        Build, test, then run
#   scripts/run.sh -h|--help  Show this help

set -euo pipefail

STACK="${STACK:-stack}"
PACKAGE="GiGtkApp"
EXECUTABLE="GiGtkApp-exe"
PKG_CONFIG_PACKAGES=(gobject-introspection-1.0 gtk4)

# Run from the project root regardless of where the script is invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; }

usage() {
  sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

check_system_deps() {
  if ! command -v pkg-config >/dev/null 2>&1; then
    err "pkg-config not found; cannot verify GTK system dependencies."
    exit 1
  fi
  local missing=0 package
  for package in "${PKG_CONFIG_PACKAGES[@]}"; do
    if ! pkg-config --exists "$package"; then
      err "Missing pkg-config package: $package"
      missing=1
    fi
  done
  if [ "$missing" -ne 0 ]; then
    cat >&2 <<'EOF'

Install GTK/GObject Introspection development packages first:
  Ubuntu/Debian: sudo apt-get install libgirepository1.0-dev libgtk-4-dev
  Fedora:        sudo dnf install gobject-introspection-devel gtk4-devel
  macOS:         brew install gtk4 gobject-introspection
EOF
    exit 1
  fi
}

do_build() {
  info "Building $PACKAGE"
  "$STACK" build --fast
}

do_test() {
  info "Running tests"
  "$STACK" test --fast
}

do_run() {
  info "Running $EXECUTABLE"
  "$STACK" run "$EXECUTABLE"
}

main() {
  local cmd="${1:-all}"
  case "$cmd" in
    -h|--help|help)
      usage
      return 0
      ;;
  esac

  check_system_deps

  case "$cmd" in
    build) do_build ;;
    test)  do_test ;;
    run)   do_run ;;
    all)
      do_build
      do_test
      do_run
      ;;
    *)
      err "Unknown command: $cmd"
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
