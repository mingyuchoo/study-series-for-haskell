# cli Invariants

| 불변조건 | 검증 |
|---|---|
| 상태와 우선순위 이름은 `Todo.Core.Types`의 이름과 같습니다. | `../tests/Todo/Cli/OptionsSpec.hs` |
| 알 수 없는 상태, 우선순위, 정렬 기준, 날짜 형식을 거부합니다. | `../tests/Todo/Cli/OptionsSpec.hs` |
| `list`의 기본값은 끝나지 않은 할 일만 보여주는 것입니다. | `../tests/Todo/Cli/OptionsSpec.hs` |
| `edit`에서 마감일 제거와 마감일 미변경을 구분합니다. | `../tests/Todo/Cli/OptionsSpec.hs` |
| 한 줄 출력은 식별자, 상태, 제목을 항상 포함합니다. | `../tests/Todo/Cli/RenderSpec.hs` |
| 빈 목록도 오류가 아니라 안내 문구를 출력합니다. | `../tests/Todo/Cli/RenderSpec.hs` |
| 오류 메시지는 표준 출력이 아니라 표준 오류로 나갑니다. | `Todo.Cli.Run`의 `abort` |
| 이미 목표 상태인 요청은 실패가 아니라 무변경 안내입니다. | `../../core/tests/Todo/Core/UseCaseSpec.hs` |
