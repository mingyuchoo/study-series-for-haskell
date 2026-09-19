# api

할 일 유스케이스를 HTTP로 노출하는 어댑터입니다. 라우트는 Servant로 타입 수준에 고정합니다.

- 공개 계약: `../../docs/contracts/api/TODO-API-v1.md`
- 라우트 지도: `../../docs/generated/route-map.md`
- 경계 결정: `../../docs/decisions/ADR-0003-api-boundary.md`
- 지역 불변조건: `./docs/invariants.md`
- 지역 아키텍처: `./docs/architecture.md`
- 실패 방식: `./docs/failure-modes.md`

## 실행

```bash
TODO_DB=todo.db TODO_API_PORT=8080 cabal run api
```

| 환경 변수 | 기본값 | 의미 |
|---|---|---|
| `TODO_DB` | `todo.db` | SQLite 파일 경로. `cli`와 공유합니다 |
| `TODO_API_PORT` | `8080` | 수신 포트 |

수신 주소는 `127.0.0.1`로 고정이며 환경 변수로 바꿀 수 없습니다. 이 API에는 인증이 없어 접근 경로 제한이 유일한 방어선입니다(`../../docs/decisions/ADR-0004-web-surface.md`). 다른 기기에서 접속하려는 시도는 연결이 거부됩니다.

## 모듈

| 모듈 | 책임 |
|---|---|
| `Todo.Api.Types` | 전송 표현과 JSON 인스턴스 |
| `Todo.Api.Routes` | 라우트 타입. 라우트의 Canonical Source |
| `Todo.Api.Server` | 핸들러와 오류 매핑 |

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

실행 파일이 있는 패키지에서는 `./scripts/run.sh run -- 인자` 로 실행할 수도 있습니다.
