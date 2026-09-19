# store Context

이 디렉터리에서는 루트 지침과 함께 다음 Canonical Context를 확인합니다.

- `../../docs/contracts/data/TODO-STORE-v1.md`
- `../../docs/decisions/ADR-0001-storage.md`
- `../../docs/incidents/INC-2026-001.md`
- `../../docs/incidents/lessons.md`
- `../../docs/tech-debt/active.md`
- `./docs/invariants.md`
- `./docs/architecture.md`
- `./docs/failure-modes.md`

## Critical Areas

스키마 변경, 마이그레이션, 인코딩 형식, 트랜잭션 경계와 연결 설정은 기존 데이터에 영향을 주며 되돌리기 어렵습니다.

- 열을 제거하거나 의미를 바꾸는 변경은 Level 3입니다. ADR과 사람의 승인이 필요합니다.
- 열을 추가하는 변경도 `schema_version`을 올리고 데이터 계약을 함께 갱신해야 합니다.
- `./schema/schema.sql`을 바꾸면 `../../scripts/context/generate-db-schema.sh`를 실행해 생성 문서를 갱신합니다.

## Do Not

- 조회 조건이나 정렬을 SQL에서 다시 구현하지 않습니다. 의미는 `Todo.Core.Filter`가 소유합니다.
- 손상된 행을 기본값으로 덮어쓰지 않습니다. `StoreError`로 실패시킵니다.
- 주석에 세미콜론을 쓰지 않습니다. 스키마 분할 규칙이 깨집니다.
