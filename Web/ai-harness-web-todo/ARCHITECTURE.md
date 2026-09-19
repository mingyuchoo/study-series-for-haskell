# Architecture

## 목적

이 문서는 시스템의 전체 구조, 구성 요소의 책임, 허용된 의존 방향과 주요 경계를 설명하는 Canonical Source입니다.

## 현재 상태

Haskell로 구현한 로컬 우선 Todo List 앱입니다. cabal 다중 패키지 프로젝트이며 다섯 개의 패키지로 이루어집니다. 저장은 SQLite이고 표면은 CLI, HTTP API, 브라우저 세 가지입니다. 세 표면 모두 사용자의 기계 안에서만 동작합니다.

- 언어와 도구: GHC 9.10, cabal 3.16
- 저장: SQLite (`src/store/schema/schema.sql`) — 근거는 `docs/decisions/ADR-0001-storage.md`
- HTTP: Servant — 근거는 `docs/decisions/ADR-0003-api-boundary.md`
- 브라우저: 서버 렌더링 HTML, 루프백 전용 — 근거는 `docs/decisions/ADR-0004-web-surface.md`

## 시스템 경계

| 구성 요소 | 책임 | 소유 데이터 | 허용된 의존 대상 |
|---|---|---|---|
| core | 도메인 규칙과 유스케이스 | 없음. 순수 계층 | 없음 |
| store | SQLite 저장과 마이그레이션 | 할 일과 태그 행, 스키마 버전 | core |
| cli | 명령줄 표면 | 없음 | core, store |
| api | HTTP 표면 | 없음 | core, store |
| web | 브라우저 표면 | 없음 | core, store |

패키지 목록의 기계적 사실은 `docs/generated/service-map.md`에, 실제 의존 그래프는 `docs/generated/dependency-graph.md`에 있습니다. 두 문서 모두 cabal 파일에서 생성됩니다.

## 의존 규칙

```text
cli ──────┐
          │
api ──────┼──> store ──> core
          │
web ──────┘
```

1. `core`는 다른 패키지에 의존하지 않습니다.
2. 도메인은 `IO`를 모릅니다. `core`는 `Control.Monad.IO.Class`, `Database.*`, `Network.*`, `System.IO`, `System.Environment`를 import하지 않습니다.
3. 부수 효과는 어댑터만 수행합니다. 저장 인터페이스는 `core`가 소유한 `TodoRepository` 타입클래스로 역전합니다.
4. 시각은 포트가 아니라 인자입니다. 경계에서 읽어 유스케이스에 주입합니다.
5. 표면 어댑터는 서로의 내부 모듈을 import하지 않습니다. `cli`, `api`, `web`은 서로를 모릅니다. 특히 `web`은 `api`를 HTTP로 호출하지 않고 유스케이스를 직접 사용합니다.
6. 전송 표현과 저장 표현은 도메인 타입과 분리합니다. 도메인 타입에 JSON, SQL, HTML 인스턴스를 붙이지 않습니다.
7. 순환 패키지 의존을 허용하지 않습니다.

이 규칙들은 문장으로만 존재하지 않습니다. `scripts/quality/architecture-check.sh`가 cabal 파일의 `build-depends`와 `core`의 import 목록을 파싱해 검사하며 CI에서 실행됩니다.

## 규칙이 한 곳에만 있어야 하는 이유

CLI, HTTP API, 브라우저는 같은 사용자에게 같은 데이터를 보여주는 세 창입니다. 창이 서로 다른 답을 주면 사용자는 어느 쪽을 믿어야 할지 알 수 없습니다(`docs/product/invariants.md`의 `PROD-INV-003`).

표면이 늘어날수록 이 약속은 지키기 어려워지는 것이 아니라 쉬워져야 합니다. 새 표면이 규칙을 복제하지 않고 호출만 한다면 창의 개수는 문제가 되지 않습니다. 복제가 시작되는 순간 개수가 곧 위험이 됩니다.

이 약속을 문서로 지키는 것은 불가능합니다. 그래서 구조로 지킵니다.

- 상태 전이는 `Todo.Core.Status`만 판단합니다.
- 조회 조건과 정렬은 `Todo.Core.Filter`만 평가합니다. 저장 계층은 SQL로 거르지 않고 전체를 읽어 도메인에 넘깁니다.
- 값 검증은 `Todo.Core.Validation`만 수행합니다.

마지막 항목에는 비용이 있습니다. 데이터가 커지면 전체를 읽어 걸러내는 방식이 느려집니다. 지금은 개인 규모를 전제하고 일관성을 택했습니다. 이 선택을 뒤집는 시점은 `ADR-0001`의 재검토 조건에 있습니다.

## 데이터와 통신

- 저장 형식은 공개 계약입니다. `docs/contracts/data/TODO-STORE-v1.md`를 따릅니다.
- HTTP 표면은 `docs/contracts/api/TODO-API-v1.md`를 따르며 버전과 호환성 정책을 가집니다.
- 이벤트 기반 통신은 사용하지 않습니다. 필요해지기 전에 도입하지 않습니다.
- 스키마와 라우트의 현재 사실은 `docs/generated`에 기계적으로 생성합니다.

## 운영 경계

- 세 표면이 같은 SQLite 파일을 동시에 열 수 있습니다. 연결 설정은 `src/store/docs/architecture.md`에 있고 근거는 `docs/incidents/INC-2026-001.md`입니다.
- 네트워크를 여는 두 표면은 `127.0.0.1`에만 바인딩하며 수신 주소를 바꾸는 설정을 제공하지 않습니다. 인증이 없으므로 접근 경로 제한이 유일한 방어선입니다. 근거는 `docs/decisions/ADR-0004-web-surface.md`입니다.
- 각 패키지는 실패 방식, 안전한 동작과 복구를 `src/*/docs/failure-modes.md`에 명시합니다.
- 이 앱에는 원격 의존성이 없습니다. 사용자 데이터는 사용자가 지정한 로컬 파일 밖으로 나가지 않습니다. 브라우저 표면도 CDN이나 원격 자산을 참조하지 않고 정적 자산을 자체 서빙합니다.

## 관련 문서

- 컨텍스트 지도: `docs/ai/INDEX.md`
- 결정 기록: `docs/decisions/INDEX.md`
- 계약: `docs/contracts/INDEX.md`
- 패키지 지도: `docs/generated/service-map.md`
