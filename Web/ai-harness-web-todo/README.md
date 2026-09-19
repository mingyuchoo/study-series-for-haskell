# Todo List

Haskell로 만든 로컬 우선 할 일 관리 앱입니다. 계정도 서버도 없이 SQLite 파일 하나에 저장하고, 같은 규칙을 명령줄, HTTP API, 브라우저 세 표면으로 제공합니다. 세 표면 모두 사용자의 기계 안에서만 동작합니다.

동시에 이 저장소는 **여러 AI 도구와 사람이 하나의 저장소 기억을 공유하는 방법**을 보여주는 예시이기도 합니다. `AGENTS.md`와 `CLAUDE.md`는 얇은 진입점이며, 실제 장기 기억은 코드, 문서, 계약, 테스트, ADR, 사고 기록과 생성된 사실에 보존합니다.

## 요구 사항

- GHC 9.10 이상
- cabal 3.16 이상

## 시작하기

```bash
cabal update && cabal build all
```

```bash
cabal run cli -- add "보고서 작성" --due 2026-09-01 --tag work --priority high
```

```bash
cabal run cli -- list
```

```text
   1  pending      ! 보고서 작성  [work]  (마감 2026-09-01)
```

HTTP API를 함께 쓰려면 같은 데이터베이스 경로를 지정합니다.

```bash
TODO_DB=todo.db TODO_API_PORT=8080 cabal run api
```

```bash
curl -s localhost:8080/todos
```

두 표면은 같은 유스케이스를 호출하므로 항상 같은 결과를 보여줍니다. 브라우저에서 보려면 세 번째 표면을 같은 경로로 띄웁니다.

```bash
TODO_DB=todo.db TODO_WEB_PORT=8081 cabal run web
```

세 표면 모두 같은 유스케이스를 호출하므로 항상 같은 결과를 보여줍니다. 두 서버 모두 `127.0.0.1`에만 바인딩합니다. 인증이 없으므로 다른 기기에서 접속할 수 없게 하는 것이 설계의 일부입니다(`docs/decisions/ADR-0004-web-surface.md`).

브라우저에서 할 일을 만들고 고치고 상태를 바꾸고 삭제할 수 있습니다. 삭제는 되돌릴 수 없으므로 확인 화면을 거칩니다.

API 서버는 `127.0.0.1`에만 바인딩합니다. 인증이 없으므로 다른 기기에서 접속할 수 없게 하는 것이 설계의 일부입니다(`docs/decisions/ADR-0004-web-surface.md`).

## 구조

| 패키지 | 책임 |
|---|---|
| `src/core` | 도메인 규칙과 유스케이스. 순수 계층이며 `IO`를 모릅니다 |
| `src/store` | SQLite 저장 어댑터 |
| `src/cli` | 명령줄 표면 |
| `src/api` | Servant HTTP 표면 |
| `src/web` | 브라우저 표면. 서버 렌더링, 루프백 전용 |

전체 구조와 의존 규칙은 `ARCHITECTURE.md`에 있습니다.

저장소 루트의 `scripts/run.sh`는 전체 코드베이스의 포맷팅, 빌드, 테스트, 실행을 한 번에 다룰 수 있는 통합 진입점입니다. 각 패키지의 지역 스크립트(`src/*/scripts/run.sh`)에 작업을 위임하므로 빌드와 테스트 방법의 정의는 한 곳에만 있습니다.

```bash
./scripts/run.sh                       # 코드 포맷팅, 빌드, 테스트를 순서대로 수행
```

```bash
./scripts/run.sh format                # Haskell 소스 코드 포맷팅 (fourmolu)
```

```bash
./scripts/run.sh web                   # 브라우저 표면 빌드 및 기동
```

```bash
./scripts/run.sh web --test --with-api # 테스트 후 브라우저 UI와 HTTP API 동시 기동
```

```bash
./scripts/run.sh cli -- list --all     # 명령줄 인터페이스(cli) 실행
```

```bash
./src/cli/scripts/run.sh test          # 한 패키지만 다룰 때는 해당 패키지의 지역 스크립트 사용
```

`./scripts/run.sh help`과 `list`로 사용 가능한 명령과 앱을 확인할 수 있습니다.

## 검증

```bash
cabal test all
```

```bash
./scripts/quality/lint.sh
```

```bash
./scripts/quality/architecture-check.sh
```

```bash
./scripts/context/validate-context.sh
```

마지막 두 검사가 이 저장소의 특징입니다. 아키텍처 검사는 cabal 파일과 import 목록을 파싱해 의존 방향과 도메인 순수성을 강제하고, 컨텍스트 검사는 문서 링크, 인덱스 등록, 생성 문서의 최신성을 확인합니다.

## 컨텍스트 체계

작업을 시작하기 전에 `docs/ai/INDEX.md`에서 관련 경로를 고릅니다.

- Context as System: 컨텍스트를 부가 문서가 아닌 시스템 구성 요소로 관리합니다.
- Map, not Manual: 진입점은 지식을 복제하지 않고 Canonical Source로 안내합니다.
- Hierarchical Retrieval: 전역, 도메인, 현재 작업의 순서로 필요한 정보만 탐색합니다.
- Preserve Why: 중요한 선택과 대안은 ADR에 남깁니다.
- Verification: 중요한 규칙은 테스트, 계약, 스키마와 정적 검사로 검증합니다.
- Consolidation: 반복해서 필요한 학습만 영구 컨텍스트로 승격합니다.
- Context Garbage Collection: 오래되거나 깨진 컨텍스트를 자동으로 탐지합니다.

생성 문서는 손으로 쓰지 않습니다. `docs/generated`의 다섯 문서는 각각 SQL 스키마, 계약 문서, Servant 라우트 타입, cabal 파일에서 기계적으로 추출됩니다.

컨텍스트의 전체 흐름은 `docs/ai/CONTEXT_LIFECYCLE.md`, 사람과 기계의 책임은 `docs/ai/OWNERSHIP.md`에서 확인합니다.

## ChatGPT Project Instructions

ChatGPT 프로젝트에는 아래처럼 짧은 지침을 두는 것을 권장합니다.

```text
소프트웨어 작업 시 docs/ai/INDEX.md를 Canonical Context의 진입점으로 사용한다.
구현 전 ARCHITECTURE.md, 관련 도메인 문서, ADR, 계약, 사고 기록을 확인한다.
도메인 규칙은 src/core에 두고 어댑터에 복제하지 않는다.
상충하는 정보에는 docs/ai/AUTHORITY.md의 우선순위를 적용하고 추측하지 않는다.
장기적으로 유효한 새 지식은 ADR, 문서, 규칙 또는 테스트에 반영한다.
```
