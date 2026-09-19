# store Invariants

| 불변조건 | 검증 |
|---|---|
| 새 할 일은 항상 `pending` 상태로 저장합니다. | `../tests/Todo/Store/SqliteSpec.hs` |
| 저장한 값과 되읽은 값이 같습니다. | `../tests/Todo/Store/SqliteSpec.hs` |
| 존재하지 않는 식별자 갱신은 새 행을 만들지 않고 `False`를 반환합니다. | `../tests/Todo/Store/SqliteSpec.hs` |
| 태그 갱신은 이전 태그를 남기지 않습니다. | `../tests/Todo/Store/SqliteSpec.hs` |
| 할 일을 삭제하면 태그도 함께 사라집니다. | `../tests/Todo/Store/SqliteSpec.hs` |
| 이미 없는 할 일의 삭제는 오류가 아니라 `False`입니다. | `../tests/Todo/Store/SqliteSpec.hs` |
| 이미 스키마가 적용된 파일을 다시 열어도 안전합니다. | `../tests/Todo/Store/SqliteSpec.hs` |
| 연결은 WAL 저널 모드를 사용합니다. | `../tests/Todo/Store/RegressionSpec.hs` |
| 세 연결이 동시에 써도 잠금 오류로 실패하지 않습니다. | `../tests/Todo/Store/RegressionSpec.hs` |
| 한 연결이 계속 읽는 동안에도 다른 연결이 쓸 수 있습니다. | `../tests/Todo/Store/RegressionSpec.hs` |
| 여러 표면이 같은 파일을 동시에 처음 열어도 실패하지 않습니다. | `../tests/Todo/Store/RegressionSpec.hs` |
| 잠금 경합으로 실패한 초기화를 유한한 횟수만큼 다시 시도합니다. | `../tests/Todo/Store/RegressionSpec.hs` |
| 잠금이 아닌 오류는 재시도하지 않고 즉시 올립니다. | `../tests/Todo/Store/RegressionSpec.hs` |

## 연결 설정의 순서

`busy_timeout`을 `journal_mode`보다 먼저 설정합니다. 저널 모드를 WAL로 바꾸는 것 자체가 배타적 잠금을 요구하므로, 순서를 바꾸면 정작 그 설정이 필요한 작업이 보호받지 못합니다. 근거는 `./architecture.md`에 있습니다.
| 해석할 수 없는 값은 기본값으로 대체하지 않고 실패시킵니다. | `Todo.Store.Sqlite`의 `StoreError` |
