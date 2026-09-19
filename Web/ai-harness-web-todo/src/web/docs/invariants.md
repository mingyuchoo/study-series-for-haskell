# web Invariants

| 불변조건 | 검증 |
|---|---|
| 사용자 입력은 이스케이프되어 렌더링됩니다. | `../tests/Todo/Web/ViewSpec.hs` |
| 화면은 외부 출처의 자산을 참조하지 않습니다. | `../tests/Todo/Web/ViewSpec.hs` |
| 상태 표시 문구와 계약에 실리는 값은 서로 다른 층입니다. | `../tests/Todo/Web/ViewSpec.hs` |
| 뷰는 받은 목록을 다시 거르거나 정렬하지 않습니다. | `../tests/Todo/Web/ViewSpec.hs` |
| 기본 목록 조건이 `cli`와 같습니다. | `../../core/tests/Todo/Core/FilterSpec.hs` |
| 조회 조건은 `Todo.Core.Filter`가 평가합니다. 웹은 조건을 만들기만 합니다. | `../tests/Todo/Web/RouteSpec.hs` |
| 알 수 없는 상태 이름과 잘못된 태그를 거부합니다. | `../tests/Todo/Web/RouteSpec.hs` |
| 음수나 숫자가 아닌 식별자는 상세 화면으로 이어지지 않습니다. | `../tests/Todo/Web/RouteSpec.hs` |
| 오류 문구가 내부 구조를 노출하지 않습니다. | `../tests/Todo/Web/RouteSpec.hs` |
| 저장소를 바꾸는 요청은 `Sec-Fetch-Site`가 `same-origin`일 때만 처리됩니다. | `../tests/Todo/Web/SecuritySpec.hs` |
| 헤더가 없는 변경 요청도 거부합니다. | `../tests/Todo/Web/SecuritySpec.hs` |
| 거부 안내가 받은 헤더 값을 화면에 되돌려 주지 않습니다. | `../tests/Todo/Web/SecuritySpec.hs` |
| 변경 경로만 쓰기로 분류됩니다. 삭제 확인 화면은 조회입니다. | `../tests/Todo/Web/RouteSpec.hs` |
| 삭제는 확인 화면을 거치며 상세 화면에서 바로 실행되지 않습니다. | `../tests/Todo/Web/ViewSpec.hs` |
| 상태 변경 단추는 `Todo.Core.Status`가 허용한 전이만 보여줍니다. | `../tests/Todo/Web/ViewSpec.hs` |
| 폼에 실리는 값은 표시 문구가 아니라 저장 값입니다. | `../tests/Todo/Web/ViewSpec.hs`, `../tests/Todo/Web/FormSpec.hs` |
| 값 검증은 `Todo.Core.Validation`이 수행합니다. 폼은 필드를 넘기기만 합니다. | `../tests/Todo/Web/FormSpec.hs` |
| 마감일의 미지정, 제거, 변경 세 경우를 구분합니다. | `../tests/Todo/Web/FormSpec.hs` |
| 포트 설정이 잘못되어도 기동에 실패하지 않고 기본값을 씁니다. | `../tests/Todo/Web/ConfigSpec.hs` |
| 데이터베이스 경로 기본값이 다른 표면과 같습니다. | `../tests/Todo/Web/ConfigSpec.hs` |

## 자동 검증에 없는 것

세 표면이 같은 데이터베이스에서 같은 목록을 보이는지는 실행 중인 세 프로세스를 비교해 수동으로 확인했습니다. 자동 테스트가 없는 이유는 어댑터가 서로를 import할 수 없어 한 테스트 스위트가 세 표면을 함께 부를 수 없기 때문입니다.

구조적 근거는 자동 검증됩니다. 세 표면 모두 `Todo.Core.UseCase.listTodos`를 호출하고, 기본 조건은 `Todo.Core.Filter.resolveStatusFilter` 하나가 정하며, 뷰가 순서를 바꾸지 않는다는 것이 각각 테스트되어 있습니다. 저장 계층에서 세 연결이 같은 확정 상태를 본다는 것도 `../../store/tests/Todo/Store/RegressionSpec.hs`가 검증합니다.

### 수동 확인 절차

표면의 기본 조건이나 정렬을 바꾸는 변경을 했다면 이 절차를 다시 실행합니다.

```bash
export TODO_DB=/tmp/surface-check.db
```

```bash
cabal run cli -- add "보고서" --due 2026-09-01 --tag work && cabal run cli -- add "장보기"
```

세 표면을 같은 경로로 띄운 뒤 비교합니다. 두 서버는 각각 다른 터미널에서 실행합니다.

```bash
cabal run web
```

```bash
cabal run api
```

```bash
cabal run cli -- list
```

```bash
curl -s 'http://127.0.0.1:8081/' | grep -oE '<a href="/todos/[0-9]+">[^<]*</a>'
```

```bash
curl -s 'http://127.0.0.1:8080/todos' | python3 -m json.tool
```

기대하는 결과는 다음과 같습니다.

| 비교 | 기대 |
|---|---|
| CLI `list`와 웹 `/` | 같은 할 일이 같은 순서로 |
| 웹 `/?all`과 API `GET /todos` | 같은 할 일이 같은 순서로 |

CLI `list`와 API `GET /todos`의 기본 결과는 다릅니다. CLI와 웹은 끝나지 않은 할 일만 보여주고 API는 전체를 반환합니다. 이것은 불일치가 아니라 표면별 기본값이며, 같은 조건을 주면 같은 답이 나옵니다.
