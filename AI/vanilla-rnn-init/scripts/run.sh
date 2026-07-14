#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly EXECUTABLE="vanilla-rnn-init-exe"

if ! command -v stack >/dev/null 2>&1; then
  echo "오류: Stack이 설치되어 있지 않음" >&2
  echo "설치 안내: https://docs.haskellstack.org/en/stable/install_and_upgrade/" >&2
  exit 127
fi

cd "${PROJECT_ROOT}"

echo "[1/3] 빌드 시작함"
stack build

echo "[2/3] 테스트 시작함"
stack test

echo "[3/3] 실행 시작함"
stack exec "${EXECUTABLE}" -- "$@"
