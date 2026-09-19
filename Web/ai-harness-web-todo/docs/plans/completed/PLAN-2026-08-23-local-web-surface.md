# Plan: 로컬 브라우저 표면 도입

- 상태: Completed
- 완료일: 2026-08-23
- 작성일: 2026-08-23
- 소유자: Todo Maintainers
- 위험 수준: Level 2
- 관련 이슈와 ADR: `../../decisions/ADR-0004-web-surface.md`, ADR-0002, ADR-0003, INC-2026-001

## Objective

사용자가 자기 기계의 브라우저에서 할 일을 보고 만들고 상태를 바꿀 수 있습니다. 데이터는 여전히 사용자가 지정한 로컬 SQLite 파일 하나에 있고, 서버는 루프백에만 바인딩하며, 계정과 네트워크 없이 시작한다는 제품 전제는 그대로입니다.

CLI, HTTP API, 웹 세 표면이 같은 입력에 항상 같은 답을 줍니다. 이 일치는 문서가 아니라 `Todo.Core.UseCase`를 함께 호출하는 구조가 지탱합니다.

## Scope

### In Scope

- `docs/product/vision.md`의 비목표에서 "그래픽 사용자 인터페이스"를 옮기는 결정과 그 근거 기록
- ADR-0004: 웹 표면의 도입 이유, 서버 렌더링 선택, 루프백 전용 전제
- 새 패키지 src/web. 서버 렌더링 HTML 어댑터이며 `core`와 `store`에만 의존합니다
- `web` 실행 파일을 `127.0.0.1`에만 바인딩
- `api` 실행 파일도 같은 방식으로 루프백 바인딩으로 교정 (아래 "선행 교정" 참조)
- 상태 변경 요청에 대한 교차 출처 방어
- `ARCHITECTURE.md`의 경계표와 의존 규칙, `scripts/quality/architecture-check.sh`의 기계 검사 갱신
- 패키지 경계 문서 6종과 테스트, 생성 문서 재생성
- 세 표면 동시 접근 회귀 테스트

### Out of Scope

- 인증, 세션, 다중 사용자. 루프백 밖에서 접속하는 순간 필요해지며 그것은 Level 3입니다
- 원격 호스팅, 기기 간 동기화. `docs/product/vision.md`의 비목표로 남습니다
- JavaScript 빌드 툴체인 (npm, vite, 번들러). 저장소는 단일 Haskell 툴체인을 유지합니다
- `TODO-API-v1` 계약 변경. JSON 표면의 라우트, 필드, 오류 코드는 그대로입니다
- SQLite 스키마 변경. 기존 데이터베이스 파일이 그대로 열립니다
- 페이지네이션과 낙관적 동시성 제어. 아래 "알려진 잔여 위험"에 남깁니다

## Context Retrieved

- `docs/product/vision.md` — 비목표 세 항목 중 "그래픽 사용자 인터페이스" 하나만 이 계획의 대상입니다. "HTTP API가 존재하는 것은 원격 사용을 위해서가 아니라 로컬 자동화를 위해서"라는 구분이 이 계획의 경계선입니다
- `docs/product/invariants.md` — `PROD-INV-003`은 두 표면이 아니라 모든 표면에 적용됩니다. `PROD-INV-005`는 이 계획이 지켜야 하는 핵심 제약입니다
- `ARCHITECTURE.md` — 의존 규칙 5 "두 어댑터는 서로의 내부 모듈을 import하지 않습니다"가 웹 표면의 배치를 결정합니다
- `docs/decisions/ADR-0003-api-boundary.md` — 전송 표현을 도메인과 분리하는 원칙이 HTML 표현에도 같이 적용됩니다
- `docs/decisions/ADR-0002-effect-boundary.md` — 시각은 포트가 아니라 경계에서 읽어 주입합니다
- `docs/incidents/INC-2026-001.md` 및 `LESSON-001` — "제품이 약속한 사용 방식이 테스트되지 않으면 그 약속이 언젠가 깨진다". 표면이 셋이 되면 동시 접근 테스트도 셋이어야 합니다
- `src/core/src/Todo/Core/UseCase.hs` — `addTodo`, `listTodos`, `getTodo`, `changeStatus`, `updateTodo`, `deleteTodo`가 웹이 호출할 전부입니다. 새 유스케이스는 필요하지 않습니다
- `src/api/app/Main.hs` — Warp의 `run`을 사용하며 (30행) 모든 인터페이스에 바인딩합니다
- `src/api/src/Todo/Api/Server.hs` — 미들웨어 없는 맨 `serve`입니다 (71행). CORS 설정이 없습니다
- `scripts/quality/architecture-check.sh` — `ALLOWED`와 `ADAPTER_PREFIX`가 하드코딩되어 있어 새 패키지는 등록 전까지 검사에 실패합니다
- `scripts/context/validate-context.sh` — 패키지마다 `AGENTS.md`, `CLAUDE.md`, `README.md`, `docs/{invariants,architecture,failure-modes}.md`, `src`, `tests`, cabal 파일을 요구합니다

## 선행 교정: api의 바인딩

이 계획의 일부이지만 웹 표면과 독립적으로 옳은 수정입니다.

`src/api/app/Main.hs`의 `run port`는 Warp 기본 설정을 쓰며 `0.0.0.0`에 바인딩합니다. `docs/contracts/api/TODO-API-v1.md`는 "신뢰할 수 있는 로컬 환경에서만 실행하는 것을 전제한다"고 쓰지만 코드는 그 전제를 강제하지 않습니다. 인증이 없는 API가 같은 네트워크의 모든 기기에 열려 있습니다.

지금까지는 API를 필요할 때만 잠깐 켜므로 노출 창이 좁았습니다. 웹 표면이 생기면 서버를 상시 켜두게 되고 노출 시간이 하루 종일로 바뀝니다. 전제를 코드로 강제하지 않은 채 사용 시간을 늘리는 것은 안 됩니다.

`runSettings`에 `setHost "127.0.0.1"`을 적용하고, 계약 문서의 "전제"를 "강제되는 제약"으로 고쳐 씁니다. 이는 운영 동작 변경이므로 계약 문서와 `src/api/docs/failure-modes.md`에 반영합니다.

## 구조 결정: 세 번째 어댑터

`web`은 `api`를 HTTP로 호출하지 않고 `core`와 `store`를 직접 사용합니다.

이유는 세 가지입니다. 첫째, `api`를 호출하면 사용자가 두 프로세스를 띄워야 하고 실패 방식이 두 배가 됩니다. 둘째, 의존 규칙 5가 어댑터 간 참조를 금지합니다. 셋째, `PROD-INV-003`을 지탱하는 것은 API 재사용이 아니라 `Todo.Core.UseCase` 공유이며, 직접 호출로도 그 근거가 그대로 성립합니다.

서버 렌더링(lucid + HTMX)을 택하고 별도 SPA를 두지 않습니다. 브라우저에서 다른 출처로 요청을 보내지 않으므로 CORS를 열 일이 없습니다. `api`에 CORS를 여는 선택은 사용자가 방문한 임의의 웹페이지가 루프백 API에 요청을 보낼 수 있게 만들므로 채택하지 않습니다.

HTML 표현은 `Todo.Web.View`가 소유하며 도메인 타입에 렌더링 인스턴스를 붙이지 않습니다. ADR-0003이 JSON에 대해 정한 원칙과 같습니다.

## Impact Analysis

### Domain

영향 없습니다. 새 상태, 새 전이, 새 검증 규칙이 없습니다. 웹은 기존 유스케이스를 호출하기만 합니다.

`docs/product/terminology.md`에는 값 이름이 "도메인, 저장소, CLI, HTTP API에서 모두 같다"고 되어 있습니다. 여기에 웹을 추가합니다. 용어의 의미는 바뀌지 않습니다.

### Code

새 패키지 `web`이 생깁니다. 의존은 `core`, `store`이며 `cli`, `api`와 동급입니다. `cabal.project`의 `packages: src/*/`가 자동으로 포함하지만 `ghc-options` 항목은 명시적으로 추가합니다.

규칙 복제 위험이 이 계획의 가장 큰 코드 리스크입니다. 정렬 순서, 마감일 강조, 상태 전이 가능 여부 같은 판단을 뷰에서 다시 계산하면 세 번째 진실이 생깁니다. 뷰는 `Todo.Core.Filter`와 `Todo.Core.Status`가 준 결과를 표시만 합니다. 예를 들어 "완료 버튼을 보일지"는 뷰의 조건문이 아니라 `Todo.Core.Status.transition`이 답합니다.

의존 방향은 바뀌지 않습니다. `core`는 여전히 순수합니다.

### Data

스키마 변경이 없습니다. 마이그레이션과 롤백이 필요하지 않습니다. 기존 데이터베이스 파일을 가진 사용자는 아무 조치 없이 새 실행 파일을 쓸 수 있고, 이전 버전 실행 파일도 계속 같은 파일을 엽니다.

### API

`TODO-API-v1`의 라우트, 필드, 오류 코드가 변하지 않습니다. `docs/generated/route-map.md`는 재생성해도 내용이 같습니다.

변하는 것은 운영 동작 하나입니다. 바인딩 주소가 계약 문서의 "Authentication and Authorization" 절에 반영됩니다.

### CLI

변경 없습니다. 명령 이름, 옵션, 출력 형식, 종료 코드가 그대로입니다.

### Events

이벤트 계약을 도입하지 않습니다.

### Security

새 입력 경로가 생깁니다. HTML 폼입니다. 값 검증은 여전히 `Todo.Core.Validation`이 수행하며 웹은 검증을 다시 구현하지 않습니다. 새로 생기는 위험은 세 가지입니다.

1. **HTML 이스케이프.** 제목과 태그는 사용자 입력입니다. lucid의 기본 이스케이프에 의존하고 `toHtmlRaw`를 사용자 값에 쓰지 않습니다. 이 금지를 src/web/AGENTS.md의 "Do Not"에 명시합니다.
2. **교차 출처 상태 변경.** 상태를 바꾸는 요청이 폼 제출이 되므로, 사용자가 방문한 임의의 웹페이지가 `localhost`로 폼을 제출할 수 있습니다. 세션 쿠키가 없어 브라우저의 SameSite 방어가 적용되지 않습니다. 상태 변경 요청에서 `Sec-Fetch-Site` 헤더를 검사하고 `same-origin`이 아니면 거부합니다. 헤더가 없는 요청도 거부합니다.
3. **바인딩 주소.** `web`과 `api` 모두 루프백 전용입니다. 위 "선행 교정" 참조.

`PROD-INV-005`는 유지됩니다. 원격 자산을 불러오지 않습니다. CSS는 인라인 또는 자체 서빙이며 CDN을 참조하지 않습니다. 외부로 요청을 보내는 의존성을 추가하지 않으므로 아키텍처 검사가 그대로 통과합니다.

오류 표시에 저장소 경로, SQL, 스택 추적을 담지 않습니다. `api`의 동일 규칙을 따릅니다.

### Operations

새 실행 파일 `web`과 새 환경 변수 `TODO_WEB_PORT`가 생깁니다. `TODO_DB`는 세 표면이 공유합니다.

동시 접근 전제가 확장됩니다. `INC-2026-001`의 WAL 모드와 busy timeout은 연결 수와 무관하게 동작하지만, 그 사고의 교훈은 "약속한 사용 방식을 테스트하라"였습니다. 지금 회귀 테스트는 두 연결을 다룹니다. 세 표면을 약속한다면 세 연결을 다뤄야 합니다.

브라우저를 켜 두면 연결이 상시 유지됩니다. 이는 지금까지 없던 사용 패턴이며 src/web/docs/failure-modes.md에 데이터베이스 파일이 사라지거나 잠기는 경우의 동작을 기록합니다.

### Tests

- 단위: src/web/tests — 뷰 렌더링, 폼 파싱, 잘못된 입력의 오류 표시
- 보안: src/web/tests — HTML 이스케이프, `Sec-Fetch-Site` 거부 경로
- 계약: 변경 없음. `src/api/tests`의 기존 계약 테스트가 그대로 통과해야 합니다
- 아키텍처: `scripts/quality/architecture-check.sh`에 `web` 등록 후 통과
- 회귀: `src/store/tests` — 세 연결 동시 쓰기
- 통합: 세 표면이 같은 데이터베이스에서 같은 결과를 보이는지 확인. `TD-002`가 지적한 공백과 같은 범주이며 이 계획에서 웹에 대해서는 만들고 CLI는 그대로 둡니다

## Steps

1. `docs/product/vision.md`의 비목표에서 GUI 항목을 옮기고, 옮긴 이유와 남긴 경계(원격 접속은 여전히 비목표)를 명시합니다. `docs/product/terminology.md`에 웹 표면을 추가합니다.
2. ADR-0004를 작성합니다. 웹 표면 도입, 서버 렌더링 선택, 루프백 전용, JS 툴체인 배제의 근거와 재검토 조건을 기록합니다. `docs/decisions/INDEX.md`에 등록합니다.
3. `api`의 바인딩을 루프백으로 교정하고 `TODO-API-v1.md`와 `src/api/docs/failure-modes.md`를 갱신합니다. 이 단계는 단독으로 검증 가능하며 여기서 멈춰도 저장소가 일관됩니다.
4. `ARCHITECTURE.md`의 경계표와 의존 규칙 다이어그램에 `web`을 추가합니다. `scripts/quality/architecture-check.sh`의 `ALLOWED`에 `web: {core, store}`, `ADAPTER_PREFIX`에 `web: Todo.Web.`을 등록합니다.
5. src/web 패키지 뼈대를 만듭니다. cabal 파일, `AGENTS.md`, `CLAUDE.md`, `README.md`, `docs/{invariants,architecture,failure-modes}.md`, `src`, `tests`, scripts/run.sh. 이 시점에 `architecture-check.sh`와 `validate-context.sh`가 통과해야 합니다.
6. 조회 경로를 구현합니다. 목록과 상세. 필터는 질의 문자열로 받아 `Todo.Core.Filter`에 넘깁니다.
7. 변경 경로를 구현합니다. 생성, 수정, 상태 변경, 삭제. 삭제는 확인 단계를 거칩니다(`PROD-INV-001`).
8. `Sec-Fetch-Site` 검사를 상태 변경 경로에 적용하고 보안 테스트를 작성합니다.
9. `src/store/tests`의 동시 접근 회귀 테스트를 세 연결로 확장합니다.
10. 생성 문서를 재생성하고 `README.md`에 웹 표면 사용법을 추가합니다.

3단계까지는 웹 표면 없이도 값어치가 있고, 5단계까지는 언제든 되돌릴 수 있습니다.

## Verification

```bash
./scripts/quality/lint.sh
```

```bash
./scripts/quality/test.sh
```

```bash
./scripts/quality/architecture-check.sh
```

```bash
./scripts/context/validate-context.sh
```

```bash
./scripts/context/generate-dependency-map.sh
```

```bash
./scripts/context/generate-route-map.sh
```

재생성 대상은 `docs/generated/service-map.md`와 `docs/generated/dependency-graph.md`입니다. `route-map.md`는 내용이 바뀌지 않아야 하며, 바뀐다면 JSON 계약을 건드린 것이므로 이 계획의 범위를 벗어난 것입니다.

성공 기준입니다.

- `cabal build all --ghc-options=-Werror`가 경고 없이 통과합니다
- 같은 데이터베이스에 대해 CLI `list`와 웹 목록과 `GET /todos`가 같은 순서로 같은 할 일을 보여줍니다
- `web`과 `api` 모두 루프백 외의 주소에서 접속되지 않습니다
- 제목에 `<script>`를 넣은 할 일이 이스케이프되어 표시됩니다
- 다른 출처에서 제출한 상태 변경 폼이 거부됩니다
- 기존 데이터베이스 파일이 마이그레이션 없이 열립니다

## Rollout and Rollback

데이터를 바꾸지 않으므로 되돌리기가 쉽습니다. `web` 패키지를 제거하고 `architecture-check.sh`의 등록을 되돌리면 이전 상태와 같습니다. 사용자 데이터에 대한 백업 요구가 없습니다.

3단계(`api` 바인딩 교정)는 예외적으로 관찰 가능한 동작 변경입니다. 다른 기기에서 `api`에 접속해 쓰던 사용자가 있다면 그 경로가 끊깁니다. 이는 의도된 것이며 계약 문서가 처음부터 지원하지 않는다고 명시한 사용 방식입니다. `README.md`와 계약 문서에 변경을 기록합니다.

중단 조건입니다.

- 뷰에서 도메인 규칙을 다시 계산하지 않고는 화면을 만들 수 없다는 것이 드러나면 중단하고 재설계합니다. 그 경우 필요한 것은 웹 표면이 아니라 `core`의 부족한 유스케이스입니다
- 서버 렌더링만으로 쓸 만한 상호작용이 안 나오면 중단합니다. JS 툴체인 도입은 이 계획의 범위가 아니며 별도 결정입니다

## Context Consolidation

완료 시 갱신합니다.

- `docs/product/vision.md` — 비목표 이동
- `docs/product/invariants.md` — `PROD-INV-003`의 소유자에 `web` 추가
- `docs/product/terminology.md` — 표면 목록
- `ARCHITECTURE.md` — 경계표, 의존 규칙, 의존 다이어그램
- `docs/decisions/ADR-0004-web-surface.md` 및 `docs/decisions/INDEX.md` — ADR 상태를 Accepted로 전환
- `docs/contracts/api/TODO-API-v1.md` — 바인딩 제약
- `docs/generated/service-map.md`, `docs/generated/dependency-graph.md`
- `scripts/quality/architecture-check.sh` — 기계 검사 등록
- src/web/ 전체 경계 문서
- `src/api/docs/failure-modes.md`
- `README.md`

## 알려진 잔여 위험

이 계획에서 해결하지 않고 남기는 것들입니다. 웹 표면을 쓰기 시작하면 드러납니다.

- **낙관적 동시성 제어가 없습니다.** 탭을 두 개 열면 나중 쓰기가 이깁니다. CLI 단독 사용에서는 없던 문제입니다. `updatedAt` 기반 조건부 갱신이 해법이며 API 계약 변경을 수반하므로 별도 계획입니다. 7단계에서 변경 경로가 생기면서 이 위험이 실제로 도달 가능해졌습니다
- **`Sec-Fetch-Site`를 보내지 않는 브라우저에서는 변경이 동작하지 않습니다.** 조회는 되고 `cli`와 `api`가 그대로 있습니다. 확인할 수 없는 출처를 허용하는 것보다 낫다고 판단했습니다
- **페이지네이션이 없고 `Todo.Core.Filter`가 전체를 읽어 메모리에서 거릅니다.** `ADR-0001`의 의식적 선택이며 재검토 조건도 거기 있습니다. 웹 목록이 느려지는 것이 그 조건에 도달했다는 신호입니다
- **목록과 태그 이름을 조회하는 경로가 없습니다.** 웹이 전체 할 일에서 추출합니다. 데이터가 커지면 전용 경로가 필요합니다
- **`TD-002`는 그대로 남습니다.** CLI 통합 테스트 공백은 이 계획이 다루지 않습니다

## 진행 상황

| 단계 | 상태 | 결과 |
|---|---|---|
| 1. 비목표 이동 | 완료 | `docs/product/vision.md`, `docs/product/terminology.md` |
| 2. ADR-0004 | 완료. 상태 Accepted | `docs/decisions/ADR-0004-web-surface.md` |
| 3. api 루프백 교정 | 완료 | `src/api/app/Main.hs`, `docs/contracts/api/TODO-API-v1.md`, 패키지 문서, `README.md` |
| 4. 아키텍처 등록 | 완료 | `ARCHITECTURE.md`, `scripts/quality/architecture-check.sh` |
| 5. 패키지 뼈대 | 완료 | src/web 전체, `cabal.project`, 생성 지도 재생성 |
| 6. 조회 경로 | 완료 | `Todo.Web.Route`, `Todo.Web.Server`, `Todo.Web.View`, `Todo.Core.Filter` |
| 7. 변경 경로 | 완료 | `Todo.Web.Form`, `Todo.Web.Route`, `Todo.Web.Server`, `Todo.Web.View` |
| 8. 출처 확인 | 완료 | `Todo.Web.Security`, `Todo.Web.Route.isWriteRoute` |
| 9. 세 연결 회귀 테스트 | 완료 | `src/store/tests/Todo/Store/RegressionSpec.hs` |
| 10. 공고화 | 완료 | 생성 문서, 테스트 범주 문서, 사고 문서, `README.md` |

9단계 검증 기록입니다. 회귀 테스트를 세 연결로 늘리고, 브라우저 탭을 열어 둔 상태를 흉내 내는 장기 읽기 사례를 더했습니다. 테스트가 실제로 사고를 잡는지 확인하기 위해 `Todo.Store.Migration.configureConnection`의 저널 모드를 `DELETE`로, busy timeout을 0으로 되돌려 보았고 세 검증이 모두 실패했습니다. 원상 복구 후 통과합니다.

10단계에서 생성기 네 개를 모두 실행했고 결과에 변화가 없었습니다. 특히 `docs/generated/route-map.md`가 바뀌지 않은 것은 `ADR-0004`가 약속한 "`TODO-API-v1` 무변경"이 지켜졌다는 뜻입니다.

7~8단계 검증 기록입니다. 실행 중인 서버에 위조 요청 세 가지를 보냈고 모두 403이며 저장소가 바뀌지 않았습니다. 헤더 없는 `POST`, `Sec-Fetch-Site: cross-site`, `Sec-Fetch-Site: same-site` 순입니다.

정상 경로는 생성 303(`Location: /todos/2`), 상태 변경 303, 수정 303, 삭제 303(`Location: /`)이었습니다. 종료 상태에서의 전이 시도는 409, 빈 제목은 400, 과거 마감일은 400과 도메인 문구("마감일 2020-01-01이 오늘 2026-08-23보다 과거입니다"), 이미 삭제한 항목의 재삭제는 404, 70 KiB 본문은 413이었습니다.

삭제 흐름을 따로 확인했습니다. `GET /todos/2/delete`를 열어도 저장소가 바뀌지 않았고, 같은 경로에 헤더 없이 `POST`하면 403, 헤더를 붙이면 303이었습니다.

제목에 `<img src=x onerror=alert(1)>`를 넣어 만든 뒤 목록, 수정 폼의 `value` 속성, 삭제 확인 화면 세 곳 모두에서 이스케이프되는 것을 확인했습니다. 태그에 `<b>`를 넣은 시도는 도메인 검증이 400으로 막았습니다.

루프백 고정은 유지됩니다. `lsof`가 `TCP 127.0.0.1:8095 (LISTEN)`을 보고했고 LAN 주소 접속은 거부됐습니다.

6단계에서 계획에 없던 변경이 하나 있었습니다. `cli`의 지역 함수 `statusFilter`(명시 상태 > 전체 보기 > 기본 `ActiveOnly`)를 웹이 그대로 필요로 했습니다. 복제하면 두 표면의 기본 목록이 갈라질 수 있으므로 `Todo.Core.Filter.resolveStatusFilter`로 승격하고 양쪽이 호출하게 했습니다. `ADR-0004`의 재검토 조건("규칙을 복제하는 압력이 생기면 웹이 아니라 도메인을 고친다")에 해당합니다. `cli`에서 지역 구현을 제거하자 import 두 개가 불필요해졌고, 기존 CLI 테스트 20개가 수정 없이 통과합니다.

6단계 검증 기록입니다. 같은 데이터베이스에 세 표면을 붙여 비교했습니다. CLI `list`와 웹 `/`가 모두 `1 보고서 작성`, `2 장보기`였고, 웹 `/?all`과 API `GET /todos`가 모두 `3, 1, 2`였습니다. 순서는 `ByDueDate` 규칙대로 마감일 순이며 마감일 없는 항목이 뒤였습니다. 제목에 `<script>`를 넣은 할 일이 실행 중인 서버에서 `&lt;script&gt;`로 이스케이프되는 것을 확인했습니다. 없는 식별자 404, 알 수 없는 상태 질의 400, 알 수 없는 경로 404, `POST` 405를 각각 확인했습니다.

3단계 검증 기록입니다. 실행 중인 서버에서 `lsof`가 `TCP 127.0.0.1:8099 (LISTEN)`를 보고했고, 루프백 접속은 200, LAN 주소 접속은 연결 거부였습니다. `cabal build all --ghc-options=-Werror` 무경고, 네 패키지 101개 예제 통과, 계약 테스트는 수정 없이 통과했습니다.

4~5단계 검증 기록입니다. `architecture-check.sh`에 `web`을 등록한 뒤, 위반을 실제로 잡는지 두 가지로 확인했습니다. `Todo.Web.View`가 `Todo.Api.Types`를 import하면 "다른 어댑터의 내부 모듈을 참조함", cabal에 `api` 의존을 추가하면 "허용되지 않은 의존 web --> api"로 각각 실패합니다. 두 경우 모두 원상 복구 후 통과합니다.

`web` 실행 파일은 `lsof` 기준 `TCP 127.0.0.1:8098 (LISTEN)`이며 LAN 주소 접속은 거부됩니다. 렌더링 결과에 외부 출처 참조가 없음을 확인했습니다.

## Result

완료했습니다. 로컬 브라우저에서 할 일을 보고, 만들고, 고치고, 상태를 바꾸고, 삭제할 수 있습니다. 데이터는 사용자가 지정한 로컬 SQLite 파일 하나에 남고 두 서버 모두 루프백에만 바인딩합니다.

### 계획과 달랐던 것

1. **`cli`의 규칙 하나를 도메인으로 올렸습니다.** 상태 조건 우선순위(명시 상태 > 전체 보기 > 기본 `ActiveOnly`)가 `Todo.Cli.Run`의 지역 함수였고 웹이 그대로 필요로 했습니다. 복제 대신 `Todo.Core.Filter.resolveStatusFilter`로 승격했습니다. 계획의 "규칙 복제 위험"과 `ADR-0004`의 재검토 조건이 예상한 상황입니다.
2. **라우트를 타입 수준에 고정하지 않았습니다.** `ADR-0003`이 Servant를 택한 근거는 라우트가 공개 계약이라는 점인데, 화면 주소에는 소비자가 없습니다. 값 수준 해석을 순수 함수로 두어 테스트가 그 자리를 대신합니다. 근거와 뒤집을 시점은 `../../../src/web/docs/architecture.md`에 있습니다.
3. **폼 본문 상한을 더했습니다.** 계획에 없었지만 변경 경로를 열면서 필요해졌습니다.

### 검증 결과

- `cabal build all --ghc-options=-Werror` 무경고
- 다섯 패키지 195개 예제 통과. `web` 90개, `core` 44개(공유 규칙 4개 포함), `store` 14개(세 연결 2개 포함)
- `lint.sh`, `architecture-check.sh`, `validate-context.sh` 통과
- 계약 테스트 28개가 수정 없이 통과. `TODO-API-v1` 무변경
- 실행 중인 서버에서 루프백 고정, CSRF 거부 3종, 삭제 확인 흐름, XSS 이스케이프 3개 위치를 확인

### 잔여 위험

"알려진 잔여 위험" 절의 항목이 그대로 남습니다. 그중 **낙관적 동시성 제어 부재**는 변경 경로가 생기면서 실제로 도달 가능해졌습니다. 탭을 두 개 열고 같은 할 일을 고치면 나중 쓰기가 이깁니다. 해법은 `updatedAt` 기반 조건부 갱신이며 API 계약 변경을 수반하므로 별도 계획입니다.

`Sec-Fetch-Site`를 보내지 않는 브라우저에서는 변경이 동작하지 않습니다. 조회는 되고 다른 두 표면이 그대로 있습니다.
