# api Invariants

| 불변조건 | 검증 |
|---|---|
| 응답의 할 일 표현은 계약이 정한 아홉 개 필드를 모두 포함합니다. | `../tests/Todo/Api/ContractSpec.hs` |
| 생성 성공은 201, 삭제 성공은 204입니다. | `../tests/Todo/Api/ContractSpec.hs` |
| 모든 오류 응답은 `code`와 `message`만 담습니다. | `../tests/Todo/Api/ContractSpec.hs` |
| 같은 상태 변경을 반복해도 200이며 오류가 아닙니다. | `../tests/Todo/Api/ContractSpec.hs` |
| 허용되지 않은 전이는 409와 `invalid_transition`입니다. | `../tests/Todo/Api/ContractSpec.hs` |
| `dueOn`의 생략과 `null`을 구분합니다. | `../tests/Todo/Api/ContractSpec.hs` |
| 검증에 실패한 입력은 저장 계층에 도달하지 않습니다. | `../tests/Todo/Api/SecuritySpec.hs` |
| 오류 메시지에 저장 경로나 SQL이 나타나지 않습니다. | `../tests/Todo/Api/SecuritySpec.hs` |
| 사용자 입력은 항상 매개변수로 바인딩하며 SQL로 이어 붙이지 않습니다. | `../tests/Todo/Api/SecuritySpec.hs` |
