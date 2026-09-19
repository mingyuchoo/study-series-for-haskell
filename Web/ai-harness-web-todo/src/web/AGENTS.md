# web Context

이 디렉터리에서는 루트 지침과 함께 다음 Canonical Context를 확인합니다.

- `../../docs/decisions/ADR-0004-web-surface.md`
- `../../docs/decisions/ADR-0003-api-boundary.md`
- `../../docs/product/invariants.md`
- `../../docs/product/terminology.md`
- `./docs/invariants.md`
- `./docs/architecture.md`
- `./docs/failure-modes.md`

## Critical Areas

이 패키지는 세 번째 표면입니다. `PROD-INV-003`은 CLI와 HTTP API뿐 아니라 여기에도 적용됩니다. 화면이 CLI나 API와 다른 답을 보이면 그것은 표시 버그가 아니라 규칙이 복제되었다는 신호입니다.

수신 주소는 `127.0.0.1` 고정입니다. 이 표면에는 인증이 없으므로 접근 경로 제한이 유일한 방어선입니다. 바인딩을 바꾸는 변경은 Level 3이며 `ADR-0004`를 대체하는 결정이 필요합니다.

상태를 바꾸는 요청은 `Sec-Fetch-Site`가 `same-origin`인 경우에만 처리합니다. 헤더가 없는 요청도 거부합니다. 세션이 없어 SameSite 쿠키 방어가 적용되지 않기 때문입니다.

어떤 경로가 그 확인을 거치는지는 `Todo.Web.Route.isWriteRoute`가 정합니다. **새 변경 경로를 추가하면 반드시 그 함수와 `./tests/Todo/Web/RouteSpec.hs`의 `allRoutes` 목록에 함께 넣습니다.** 넣지 않으면 확인 없이 통과합니다.

## Do Not

- 도메인 타입에 렌더링 인스턴스를 붙이지 않습니다. HTML 표현은 `Todo.Web.View`가 따로 소유합니다.
- 사용자 값에 `toHtmlRaw`를 사용하지 않습니다. 이스케이프를 우회하는 경로를 만들지 않습니다.
- 뷰에서 도메인 규칙을 다시 계산하지 않습니다. 정렬 순서는 `Todo.Core.Filter`, 전이 가능 여부는 `Todo.Core.Status.transition`이 답합니다. "완료 버튼을 보일지"는 뷰의 조건문이 아닙니다.
- 다른 어댑터를 참조하지 않습니다. `api`를 HTTP로 호출하지 않고 유스케이스를 직접 사용합니다.
- 외부 출처의 스타일시트, 스크립트, 글꼴, 이미지를 참조하지 않습니다. 정적 자산은 자체 서빙합니다.
- JavaScript 빌드 툴체인을 도입하지 않습니다. 필요해지면 `ADR-0004`를 재검토합니다.
- 오류 화면에 저장소 경로, SQL, 스택 추적을 담지 않습니다. 요청자가 보낸 헤더 값도 화면에 되돌려 주지 않습니다.
- 삭제를 상세 화면의 단추로 두지 않습니다. 확인 화면을 거칩니다(`PROD-INV-001`).
- `GET`으로 저장소를 바꾸지 않습니다. 변경은 모두 `POST`입니다.
- 메서드를 숨은 필드로 위장하지 않습니다. 경로에 동작을 적습니다.
