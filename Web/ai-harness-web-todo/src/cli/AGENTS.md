# cli Context

이 디렉터리에서는 루트 지침과 함께 다음 Canonical Context를 확인합니다.

- `../../docs/domain/task.md`
- `../../docs/product/terminology.md`
- `../../docs/product/invariants.md`
- `./docs/invariants.md`
- `./docs/architecture.md`
- `./docs/failure-modes.md`

## Critical Areas

명령 이름, 옵션 이름, 출력 형식과 종료 코드는 사용자와 스크립트가 함께 의존하는 표면입니다. 변경은 계약 변경으로 취급하고 `Todo.Cli.RenderSpec`과 `Todo.Cli.OptionsSpec`을 함께 갱신합니다.

`rm`은 되돌릴 수 없습니다. 사용자가 명시적으로 요청하지 않은 경로에서 호출하지 않습니다.

## Do Not

- 상태 전이 규칙이나 조회 규칙을 여기서 다시 구현하지 않습니다. `Todo.Core.UseCase`를 호출합니다.
- 상태와 우선순위 이름을 새로 만들지 않습니다. `Todo.Core.Types`의 이름을 그대로 노출해 HTTP API와 어휘를 맞춥니다.
- 검증 오류를 성공처럼 출력하지 않습니다. 표준 오류로 보내고 0이 아닌 코드로 종료합니다.
