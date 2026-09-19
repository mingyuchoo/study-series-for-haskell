# cli

할 일 유스케이스를 명령줄로 노출하는 어댑터입니다.

- 지역 불변조건: `./docs/invariants.md`
- 지역 아키텍처: `./docs/architecture.md`
- 실패 방식: `./docs/failure-modes.md`

## 사용

```bash
cabal run cli -- add "보고서 작성" --due 2026-09-01 --tag work --priority high
```

```bash
cabal run cli -- list --all --sort priority
```

데이터베이스 경로는 `--db`, 환경 변수 `TODO_DB`, 기본값 `todo.db` 순으로 정해집니다. `api`와 같은 경로를 쓰면 두 표면이 같은 데이터를 봅니다.

## 명령

| 명령 | 설명 |
|---|---|
| `add TITLE` | 할 일을 추가합니다 |
| `list` | 할 일을 조회합니다. 기본은 끝나지 않은 항목만 |
| `start ID` | 진행 중으로 표시합니다 |
| `done ID` | 완료로 표시합니다 |
| `reopen ID` | 대기 상태로 되돌립니다 |
| `archive ID` | 보관합니다 |
| `edit ID` | 내용을 수정합니다 |
| `rm ID` | 영구 삭제합니다 |

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
