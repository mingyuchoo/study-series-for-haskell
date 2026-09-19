# Data Contract: Todo Store

- 상태: Active
- 소유 패키지: store
- 소비자: cli, api, web
- 버전: v1
- 분류: Confidential

## Meaning

사용자의 할 일과 그 태그를 담는 로컬 SQLite 데이터베이스입니다. 사용자가 무엇을 언제까지 하려 하는지를 담으므로 개인 정보로 취급합니다.

기계적 스키마는 `../../generated/db-schema.md`에 있고 원본은 `src/store/schema/schema.sql`입니다. 이 문서는 스키마가 설명하지 못하는 의미와 정책을 담습니다.

## Schema

### `todos`

| 열 | 타입 | 의미와 제약 |
|---|---|---|
| `id` | INTEGER | 저장소가 부여하는 식별자. 재사용하지 않습니다 |
| `title` | TEXT | 정규화된 제목. 비어 있지 않으며 200자 이하 |
| `list_id` | TEXT | 목록 이름. 태그와 같은 문자 규칙을 따릅니다 |
| `status` | TEXT | `pending`, `in_progress`, `done`, `archived` 중 하나 |
| `priority` | TEXT | `low`, `normal`, `high`, `urgent` 중 하나 |
| `due_on` | TEXT 또는 NULL | `YYYY-MM-DD` |
| `created_at` | TEXT | UTC ISO 8601. 생성 후 바뀌지 않습니다 |
| `updated_at` | TEXT | UTC ISO 8601. 실제 변경이 있을 때만 갱신합니다 |

### `todo_tags`

| 열 | 타입 | 의미와 제약 |
|---|---|---|
| `todo_id` | INTEGER | `todos.id` 참조. 할 일이 사라지면 함께 삭제됩니다 |
| `tag` | TEXT | 소문자로 정규화된 태그. 32자 이하 |

### `schema_version`

적용된 스키마 버전과 시각을 기록합니다. 현재 버전은 1입니다.

## 형식 규칙

1. 시각은 UTC ISO 8601 문자열로 저장합니다. SQLite의 날짜 함수에 의존하지 않습니다.
2. 날짜는 `YYYY-MM-DD` 문자열로 저장합니다.
3. 상태와 우선순위는 `Todo.Core.Types`의 안정적인 이름을 그대로 저장합니다. 정수 코드로 저장하지 않습니다. 사람이 파일을 직접 열어 읽을 수 있어야 하고, 값 추가가 기존 데이터의 의미를 흔들지 않게 하기 위함입니다.

## Ownership and Access

- 쓰기 권한은 `store`에만 있습니다. `cli`, `api`, `web`은 `TodoRepository` 포트를 통해서만 접근합니다.
- 세 표면이 같은 파일을 동시에 열 수 있습니다. 동시성 처리 방식은 `src/store/docs/architecture.md`에 있습니다.
- 데이터베이스 파일 자체는 사용자의 로컬 파일 시스템에 있으며 별도의 접근 제어가 없습니다.

## Lifecycle

- 생성: 사용자의 명시적 요청으로만 만들어집니다.
- 보존: 자동 삭제나 만료가 없습니다. 보관(`archived`)은 삭제가 아니라 상태입니다.
- 삭제: `DELETE`와 `rm`만 행을 지웁니다. 되돌릴 수 없으므로 사용자의 명시적 요청 없이 호출하지 않습니다.
- 익명화: 정책이 없습니다. 로컬 단일 사용자 전제이므로 필요해지면 계약과 함께 도입합니다.

## Compatibility and Migration

- 열 추가는 하위 호환입니다. 기본값을 두고 `schema_version`을 올립니다.
- 열 제거, 이름 변경, 타입 변경, 값 집합 축소는 호환을 깨는 변경이며 Level 3입니다. ADR, 마이그레이션, 백업 절차와 사람의 승인이 필요합니다.
- 현재 되돌리는 마이그레이션이 없습니다. 이 한계는 `../../tech-debt/active.md`의 `TD-001`로 관리합니다.

## Verification

- 왕복과 경계 조건: `src/store/tests/Todo/Store/SqliteSpec.hs`
- 동시 접근 회귀: `src/store/tests/Todo/Store/RegressionSpec.hs`
- 생성 문서 일치: `scripts/context/generate-db-schema.sh --check`
