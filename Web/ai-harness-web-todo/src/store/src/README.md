# store Source

SQLite 저장 어댑터입니다. `core`가 정의한 포트를 구현하며 그 반대 방향으로 의존하지 않습니다.

모듈별 책임은 `../README.md`, 경계와 연결 설정은 `../docs/architecture.md`에 있습니다.

## 배치 규칙

- 스키마는 `../schema/schema.sql`에만 둡니다. Haskell 코드에 SQL DDL 사본을 만들지 않습니다.
- 인코딩과 디코딩은 `Todo.Store.Sqlite`에 모읍니다. 저장 형식이 여러 모듈로 흩어지면 계약을 추적할 수 없습니다.
- 조회 조건을 SQL의 `WHERE`로 옮기지 않습니다. 조회 의미는 `Todo.Core.Filter`가 소유합니다.
- 쓰기는 트랜잭션 안에서 수행합니다.
