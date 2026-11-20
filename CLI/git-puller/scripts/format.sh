#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C.UTF-8

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

find packages apps -name '*.hs' -exec fourmolu --mode inplace {} +
find packages apps -name '*.hs' -exec stylish-haskell --inplace {} +
