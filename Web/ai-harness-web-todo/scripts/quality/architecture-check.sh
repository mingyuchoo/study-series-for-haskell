#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

failed=0

# 1. 패키지마다 지역 컨텍스트와 소스 및 테스트 위치가 있어야 합니다.
for package in src/*; do
  [[ -d "$package" ]] || continue
  for path in AGENTS.md CLAUDE.md README.md docs/invariants.md docs/architecture.md docs/failure-modes.md src tests; do
    if [[ ! -e "$package/$path" ]]; then
      printf '패키지 경계 문서 또는 디렉터리가 없습니다: %s/%s\n' "$package" "$path" >&2
      failed=1
    fi
  done
  if ! compgen -G "$package/*.cabal" >/dev/null; then
    printf 'cabal 파일이 없습니다: %s\n' "$package" >&2
    failed=1
  fi
done

[[ "$failed" -eq 0 ]] || exit 1

# 2. 의존 방향과 도메인 순수성은 기계적으로 검사합니다.
python3 - "$repo_root" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
errors: list[str] = []

# ARCHITECTURE.md가 정의한 허용된 내부 의존입니다.
ALLOWED = {
    "core": set(),
    "store": {"core"},
    "cli": {"core", "store"},
    "api": {"core", "store"},
    "web": {"core", "store"},
}

# core는 순수 도메인이므로 효과를 다루는 모듈을 import하지 않습니다.
FORBIDDEN_CORE_IMPORTS = (
    "Control.Concurrent",
    "Control.Monad.IO.Class",
    "Data.IORef",
    "Database.",
    "Network.",
    "System.Environment",
    "System.IO",
    "System.Process",
)

cabal_files = sorted((root / "src").glob("*/*.cabal"))
if not cabal_files:
    print("src 아래에서 cabal 파일을 찾지 못했습니다.", file=sys.stderr)
    raise SystemExit(1)

package_names = {}
for cabal in cabal_files:
    text = cabal.read_text(encoding="utf-8")
    match = re.search(r"^name:\s*(\S+)", text, re.MULTILINE)
    if not match:
        errors.append(f"{cabal.relative_to(root)}: name 필드가 없습니다")
        continue
    package_names[cabal] = match.group(1)

internal = set(package_names.values())

for cabal, name in package_names.items():
    text = cabal.read_text(encoding="utf-8")
    depends = set()
    for block in re.findall(r"^\s*build-depends:(.*?)(?=^\s*\S+:|\Z)", text, re.MULTILINE | re.DOTALL):
        for entry in block.split(","):
            token = entry.strip().split()
            if token and token[0] in internal:
                depends.add(token[0])
    depends.discard(name)

    if name not in ALLOWED:
        errors.append(f"{cabal.relative_to(root)}: 의존 규칙에 등록되지 않은 패키지 {name}")
        continue

    forbidden = depends - ALLOWED[name]
    for target in sorted(forbidden):
        errors.append(f"{name}: 허용되지 않은 의존 {name} --> {target}")

# 도메인 계층의 순수성을 검사합니다.
for module in sorted((root / "src/core/src").rglob("*.hs")):
    for line in module.read_text(encoding="utf-8").splitlines():
        if not line.startswith("import "):
            continue
        target = line.removeprefix("import ").removeprefix("qualified ").split()[0]
        for banned in FORBIDDEN_CORE_IMPORTS:
            if target.startswith(banned):
                errors.append(
                    f"{module.relative_to(root)}: 순수 도메인이 효과 모듈을 import함: {target}"
                )

# 어댑터가 다른 어댑터의 모듈을 직접 import하지 않는지 검사합니다.
ADAPTER_PREFIX = {
    "store": "Todo.Store.",
    "cli": "Todo.Cli.",
    "api": "Todo.Api.",
    "web": "Todo.Web.",
}
for package, prefix in ADAPTER_PREFIX.items():
    for other, other_prefix in ADAPTER_PREFIX.items():
        if other == package or other in ALLOWED[package]:
            continue
        for module in sorted((root / "src" / package).rglob("*.hs")):
            for line in module.read_text(encoding="utf-8").splitlines():
                if line.startswith("import ") and other_prefix in line:
                    errors.append(
                        f"{module.relative_to(root)}: 다른 어댑터의 내부 모듈을 참조함: {other_prefix}"
                    )

if errors:
    print("아키텍처 규칙 위반을 발견했습니다:", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    raise SystemExit(1)

print("의존 방향과 도메인 순수성 검사 통과")
PY

printf '아키텍처 규칙 검사 통과\n'
