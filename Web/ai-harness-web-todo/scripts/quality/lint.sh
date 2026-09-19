#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

ran=0

# 형식 검사. fourmolu가 없으면 건너뛰고 그 사실을 알립니다.
if command -v fourmolu >/dev/null 2>&1; then
  fourmolu --mode check $(find src -name '*.hs' -not -path '*/dist-newstyle/*')
  printf 'fourmolu 형식 검사 통과\n'
  ran=1
else
  printf 'fourmolu가 없어 형식 검사를 건너뜁니다.\n'
fi

# 정적 제안 검사. hlint가 없으면 건너뜁니다.
if command -v hlint >/dev/null 2>&1; then
  hlint src
  printf 'hlint 검사 통과\n'
  ran=1
else
  printf 'hlint가 없어 정적 제안 검사를 건너뜁니다.\n'
fi

# 타입 검사. 경고를 오류로 승격해 DEFINITION_OF_DONE의 무경고 요구를 강제합니다.
if command -v cabal >/dev/null 2>&1; then
  cabal build all --ghc-options=-Werror
  printf 'GHC 무경고 빌드 통과\n'
  ran=1
else
  printf 'cabal이 없어 타입 검사를 건너뜁니다.\n'
fi

if [[ "$ran" -eq 0 ]]; then
  printf 'Haskell 도구가 하나도 없어 셸 문법만 검사합니다.\n'
fi

# 저장소의 모든 셸 스크립트를 문법 검사합니다. 패키지 지역 스크립트도 포함합니다.
for script in scripts/*.sh scripts/context/*.sh scripts/quality/*.sh src/*/scripts/*.sh; do
  [[ -f "$script" ]] || continue
  bash -n "$script"
done

printf '린트 단계 통과\n'
