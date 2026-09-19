# core

할 일 도메인 규칙과 애플리케이션 유스케이스를 담은 순수 라이브러리입니다.

이 패키지는 부수 효과를 수행하지 않습니다. 저장은 `Todo.Core.Repository`의 포트로 역전하고, 시각은 경계에서 주입받습니다. 덕분에 CLI와 HTTP API가 같은 규칙을 공유하면서도 서로를 알지 못합니다.

- 도메인 의미: `../../docs/domain/task.md`
- 지역 불변조건: `./docs/invariants.md`
- 지역 아키텍처: `./docs/architecture.md`
- 실패 방식: `./docs/failure-modes.md`

## 모듈

| 모듈 | 책임 |
|---|---|
| `Todo.Core.Types` | 도메인 어휘와 개체 |
| `Todo.Core.Status` | 허용된 상태 전이 |
| `Todo.Core.Validation` | 값 객체의 유일한 생성 경로 |
| `Todo.Core.Filter` | 조회 조건과 정렬 |
| `Todo.Core.Repository` | 저장 포트 |
| `Todo.Core.UseCase` | 유스케이스 조합 |

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
