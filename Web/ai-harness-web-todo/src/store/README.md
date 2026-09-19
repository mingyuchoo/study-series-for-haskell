# store

`core`가 정의한 `TodoRepository` 포트의 SQLite 구현입니다.

저장 형식은 공개 계약이므로 임의로 바꾸지 않습니다. 스키마 원본은 `./schema/schema.sql`이며 컴파일 시점에 임베드되므로 실행 파일과 스키마가 어긋날 수 없습니다.

- 데이터 계약: `../../docs/contracts/data/TODO-STORE-v1.md`
- 저장 기술 결정: `../../docs/decisions/ADR-0001-storage.md`
- 지역 불변조건: `./docs/invariants.md`
- 지역 아키텍처: `./docs/architecture.md`
- 실패 방식: `./docs/failure-modes.md`

## 모듈

| 모듈 | 책임 |
|---|---|
| `Todo.Store.Migration` | 스키마 적용, 연결 설정, 버전 기록 |
| `Todo.Store.Sqlite` | `TodoRepository` 인스턴스와 인코딩 |

## 빌드와 검증

이 패키지만 다룰 때는 지역 스크립트를 사용합니다. 다섯 패키지 모두 같은 인터페이스를 가집니다.

```bash
./scripts/run.sh          # 빌드 (기본값)
```

```bash
./scripts/run.sh test     # 테스트
```

```bash
./scripts/run.sh help     # 사용 가능한 명령
```

전체 패키지를 다루려면 루트의 `../../scripts/run.sh`를 사용합니다.

저장소 전체 검증은 루트의 `../../scripts/quality`와 `../../scripts/context` 아래 스크립트를 사용합니다.
