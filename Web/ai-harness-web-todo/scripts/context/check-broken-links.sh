#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

python3 - "$repo_root" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote

root = Path(sys.argv[1]).resolve()
errors: list[str] = []
markdown_link = re.compile(r"(?<!!)\[[^\]]+\]\(([^)]+)\)")
repository_path = re.compile(
    r"`((?:\.\.?/|docs/|src/|scripts/|tests/)[^`\s]+|(?:AGENTS|CLAUDE|ARCHITECTURE|README)\.md|cabal\.project)`"
)

for document in sorted(root.rglob("*.md")):
    if ".git" in document.parts or "dist-newstyle" in document.parts:
        continue
    text = document.read_text(encoding="utf-8")
    candidates: list[tuple[str, bool]] = []
    candidates.extend((target, True) for target in markdown_link.findall(text))
    candidates.extend((target, False) for target in repository_path.findall(text))

    for raw_target, is_markdown_link in candidates:
        target = raw_target.strip().split(maxsplit=1)[0].strip("<>")
        target = unquote(target.split("#", 1)[0])
        if not target or target.startswith(("http://", "https://", "mailto:", "#")):
            continue
        if any(token in target for token in ("*", "{", "}", "$")):
            continue

        if is_markdown_link or target.startswith(("./", "../")):
            resolved = (document.parent / target).resolve()
        else:
            resolved = (root / target).resolve()

        try:
            resolved.relative_to(root)
        except ValueError:
            errors.append(f"{document.relative_to(root)}: 저장소 밖을 가리킴: {raw_target}")
            continue

        if not resolved.exists():
            errors.append(f"{document.relative_to(root)}: 대상 없음: {raw_target}")

if errors:
    print("깨진 문서 참조를 발견했습니다:", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    raise SystemExit(1)

print("문서 링크 검사 통과")
PY
