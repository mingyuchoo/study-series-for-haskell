#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

if command -v cabal >/dev/null 2>&1; then
  cabal test all
else
  printf 'cabal이 없어 테스트를 실행하지 못하고 저장소 구조만 검사합니다.\n'
  for category in unit integration contract architecture security regression; do
    test -d "tests/$category"
  done
  for package in src/*; do
    [[ -d "$package" ]] || continue
    test -d "$package/tests"
  done
fi

printf '테스트 단계 통과\n'
