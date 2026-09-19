# core Failure Modes

순수 계층이므로 런타임 실패가 아니라 잘못된 값과 잘못된 요청이 실패 방식입니다.

| 실패 방식 | 탐지 | 안전한 동작 | 복구 |
|---|---|---|---|
| 정규화되지 않은 입력 | `Todo.Core.Validation`의 스마트 생성자 | `ValidationError`로 거부 | 어댑터가 사용자 오류로 변환 |
| 허용되지 않은 상태 전이 | `Todo.Core.Status.transition` | 전이 거부, 저장소 미변경 | 호출자에게 현재 상태를 알림 |
| 같은 상태로의 중복 요청 | `transition`의 `SameStatus` | 저장소를 건드리지 않고 성공 처리 | 없음. 정상 흐름입니다 |
| 존재하지 않는 식별자 | 유스케이스의 `findTodo` 결과 | `TodoNotFound` 반환 | 어댑터가 404 또는 오류 메시지로 변환 |
| 저장 직전에 사라진 할 일 | `replaceTodo`의 반환값 | 성공으로 위장하지 않고 `TodoNotFound` | 호출자가 재조회 |
