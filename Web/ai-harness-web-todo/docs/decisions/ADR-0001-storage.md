# ADR-0001: 저장 기술 선택

- 상태: Accepted
- 날짜: 2026-08-22
- 결정자: Todo Maintainers
- 관련 이슈: 없음
- 대체 관계: 없음

## Context

제품은 로컬 우선을 전제합니다(`../product/vision.md`). 계정도 서버도 없이 사용자의 기계에 데이터를 둡니다. 동시에 CLI와 HTTP API 두 프로세스가 같은 데이터를 볼 수 있어야 합니다.

데이터 규모는 개인의 할 일 수준으로 수천 건을 넘지 않습니다. 조회 패턴은 상태와 태그와 목록으로 거르고 정렬하는 것이 전부입니다.

## Decision Drivers

- 두 프로세스의 동시 접근에서 데이터가 깨지지 않아야 합니다.
- 부분 쓰기가 남지 않아야 합니다. 할 일과 태그가 따로 저장되면 안 됩니다.
- 사용자가 도구 없이도 자기 데이터를 열어볼 수 있어야 합니다.
- 설치와 실행에 별도 서버 프로세스가 필요하지 않아야 합니다.
- 스키마를 문서화하고 변경 경로를 남길 수 있어야 합니다.

## Considered Options

1. SQLite (`sqlite-simple`)
2. JSON 파일 (`aeson`)
3. `persistent` + SQLite
4. 인메모리 저장 후 종료 시 스냅샷

## Decision

SQLite를 `sqlite-simple`로 직접 사용합니다. 스키마 원본은 `src/store/schema/schema.sql` 하나이며 Haskell 코드가 컴파일 시점에 임베드합니다.

연결마다 WAL 저널 모드, 5초 busy timeout, 외래 키를 켭니다.

## Why

JSON 파일은 시작하기 쉽지만 두 프로세스가 동시에 쓸 때 안전한 갱신을 직접 구현해야 합니다. 파일 잠금과 원자적 교체를 손으로 만드는 것은 SQLite가 이미 해결한 문제를 다시 푸는 일입니다. 게다가 파일 전체를 읽고 쓰므로 부분 갱신에서 사고 가능성이 큽니다.

`persistent`는 마이그레이션 자동화를 제공하지만 스키마의 Canonical Source가 Template Haskell 선언으로 옮겨갑니다. 그러면 `docs/generated/db-schema.md`를 생성하려면 빌드가 필요해지고, Context Integrity 검사가 Haskell 툴체인에 의존하게 됩니다. 지금 규모에서 자동 마이그레이션이 주는 이득보다 이 결합이 더 비쌉니다.

인메모리 저장은 `PROD-INV-002`(저장 확인 후 유실 없음)를 만족할 수 없습니다.

SQLite는 서버 프로세스가 없고, 트랜잭션을 제공하며, 파일 하나이고, `sqlite3` 명령으로 누구나 열어볼 수 있습니다. 사용자가 도구를 떠나도 데이터가 남는다는 제품 약속과 맞습니다.

## Consequences

### Positive

- 트랜잭션으로 할 일과 태그의 부분 저장을 막습니다.
- WAL 모드로 두 표면의 동시 접근을 처리합니다.
- 스키마를 SQL 파일로 남기므로 생성 문서가 빌드 없이 만들어집니다.
- 사용자가 표준 도구로 자기 데이터를 조회할 수 있습니다.

### Negative

- `sqlite-simple`은 스키마와 Haskell 타입의 일치를 컴파일 시점에 보장하지 않습니다. 열 순서와 행 타입의 일치를 사람이 지켜야 하며, `Todo.Store.Sqlite`의 `selectFrom`에 그 규칙을 주석으로 남겼습니다.
- 마이그레이션을 손으로 작성해야 합니다.
- C 라이브러리 의존이 생겨 빌드가 순수 Haskell보다 무겁습니다.

### Risks and Mitigations

- 위험: 스키마와 코드가 어긋납니다. 완화: 스키마 파일을 임베드해 사본을 없애고, 왕복 테스트로 검증합니다.
- 위험: 마이그레이션 누락으로 오래된 파일에서 실패합니다. 완화: `schema_version` 기록과 `TD-001` 추적.

## Verification

- 왕복과 경계 조건: `src/store/tests/Todo/Store/SqliteSpec.hs`
- 동시 접근: `src/store/tests/Todo/Store/RegressionSpec.hs`
- 생성 문서 일치: `scripts/context/generate-db-schema.sh --check`

## Revisit Conditions

- 기기 간 동기화가 비목표에서 빠질 때.
- 데이터 규모가 수십만 건을 넘거나 조회가 느려질 때.
- 마이그레이션이 세 개를 넘어 손으로 관리하기 어려워질 때. 그때 `persistent` 또는 전용 마이그레이션 도구를 다시 검토합니다.
