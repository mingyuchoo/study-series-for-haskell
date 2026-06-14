#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MAKE_CMD="${MAKE:-make}"

cd "${PROJECT_ROOT}"

"${MAKE_CMD}" build
"${MAKE_CMD}" test
"${MAKE_CMD}" run
