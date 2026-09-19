# core Invariants

| 불변조건 | 검증 |
|---|---|
| 상태 전이는 `allowedTransitions`가 허용한 것만 수행합니다. | `../tests/Todo/Core/StatusSpec.hs` |
| 어떤 상태도 자기 자신으로의 전이를 허용 목록에 담지 않습니다. | `../tests/Todo/Core/StatusSpec.hs` |
| `Archived`는 종료 상태이며 나가는 전이가 없습니다. | `../tests/Todo/Core/StatusSpec.hs` |
| 같은 상태로의 변경 요청은 오류가 아니라 무변경으로 처리합니다. | `../tests/Todo/Core/UseCaseSpec.hs` |
| 제목과 태그와 목록 이름은 `Todo.Core.Validation`을 통해서만 만듭니다. | `../tests/Todo/Core/ValidationSpec.hs` |
| 태그는 소문자로 정규화하며 정규화 후 중복은 하나로 합칩니다. | `../tests/Todo/Core/ValidationSpec.hs` |
| 부분 수정은 지정하지 않은 필드를 보존합니다. | `../tests/Todo/Core/UseCaseSpec.hs` |
| 마감일이 없는 할 일은 마감일 정렬에서 항상 뒤로 갑니다. | `../tests/Todo/Core/FilterSpec.hs` |
| 이 패키지는 시각을 스스로 읽지 않습니다. | `../../../scripts/quality/architecture-check.sh` |

각 항목은 실행 가능한 검증과 연결되어 있어야 합니다. 검증 없는 규칙은 여기에 두지 않습니다.
