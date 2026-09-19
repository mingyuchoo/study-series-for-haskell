# web

할 일 유스케이스를 브라우저로 노출하는 어댑터입니다. 서버에서 HTML을 렌더링하며 루프백에만 바인딩합니다.

- 경계 결정: `../../docs/decisions/ADR-0004-web-surface.md`
- 도입 계획과 결과: `../../docs/plans/completed/PLAN-2026-08-23-local-web-surface.md`
- 지역 불변조건: `./docs/invariants.md`
- 지역 아키텍처: `./docs/architecture.md`
- 실패 방식: `./docs/failure-modes.md`

## 현재 상태

조회와 변경이 모두 동작합니다.

| 주소 | 의미 |
|---|---|
| `/` | 목록. 기본은 끝나지 않은 할 일만 |
| `/?all` | 전체 |
| `/?status=done` | 그 상태만 |
| `/?tag=work` | 태그로 거르기. 여러 번 지정하면 모두 가진 할 일만 |
| `/?list=home` | 목록으로 거르기 |
| `/todos/1` | 상세. 고치기와 상태 바꾸기 폼이 있습니다 |
| `/todos/1/delete` | 삭제 확인 |

만들기는 목록 화면 위쪽의 폼입니다. 삭제는 확인 화면을 거쳐야 실행됩니다.

기본 목록이 `cli`의 `list`와 같습니다. 두 표면 모두 `Todo.Core.Filter.resolveStatusFilter`를 쓰기 때문입니다. `api`는 스크립트가 쓰는 표면이므로 기본값 없이 전체를 반환합니다.

## 변경 요청의 출처 확인

변경 요청은 `Sec-Fetch-Site: same-origin`인 경우에만 처리합니다. 이 표면에는 세션이 없어 쿠키 기반 CSRF 방어가 적용되지 않기 때문입니다. 화면의 폼을 쓰면 브라우저가 헤더를 붙이므로 신경 쓸 일이 없지만, `curl`로 변경을 시험하려면 직접 붙여야 합니다.

```bash
curl -X POST -H 'Sec-Fetch-Site: same-origin' -d 'title=장보기' http://127.0.0.1:8081/todos
```

## 실행

```bash
TODO_DB=todo.db TODO_WEB_PORT=8081 cabal run web
```

| 환경 변수 | 기본값 | 의미 |
|---|---|---|
| `TODO_DB` | `todo.db` | SQLite 파일 경로. `cli` 및 `api`와 공유합니다 |
| `TODO_WEB_PORT` | `8081` | 수신 포트 |

수신 주소는 `127.0.0.1`로 고정이며 환경 변수로 바꿀 수 없습니다. 이 표면에는 인증이 없어 접근 경로 제한이 유일한 방어선입니다. 다른 기기에서 접속하려는 시도는 연결이 거부됩니다.

## 모듈

| 모듈 | 책임 |
|---|---|
| `Todo.Web.Config` | 환경 변수 값의 해석. 순수 함수 |
| `Todo.Web.Route` | 경로와 질의 해석, 쓰기 여부 분류. 순수 함수 |
| `Todo.Web.Form` | 폼 본문 해석. 순수 함수 |
| `Todo.Web.Security` | 변경 요청의 출처 확인. 순수 함수 |
| `Todo.Web.Server` | 유스케이스 호출과 응답 |
| `Todo.Web.View` | HTML 표현. 도메인 타입에 렌더링 인스턴스를 붙이지 않습니다 |

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
