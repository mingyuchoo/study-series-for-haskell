# api Context

이 디렉터리에서는 루트 지침과 함께 다음 Canonical Context를 확인합니다.

- `../../docs/contracts/api/TODO-API-v1.md`
- `../../docs/contracts/INDEX.md`
- `../../docs/decisions/ADR-0003-api-boundary.md`
- `../../docs/product/invariants.md`
- `./docs/invariants.md`
- `./docs/architecture.md`
- `./docs/failure-modes.md`

## Critical Areas

요청과 응답의 필드 이름, 오류 코드, HTTP 상태 매핑은 공개 계약입니다. 소비자를 깨뜨리는 변경에는 새 버전과 폐기 계획이 필요합니다.

`Todo.Api.Routes`는 `../../docs/generated/route-map.md`의 생성 원본입니다. 라우트를 바꾸면 `../../scripts/context/generate-route-map.sh`를 실행합니다.

이 API에는 인증이 없습니다. 인증이나 다중 사용자 개념을 도입하는 변경은 Level 3이며 ADR과 사람의 승인이 필요합니다.

## Do Not

- 도메인 타입에 JSON 인스턴스를 붙이지 않습니다. 전송 표현은 이 패키지가 따로 소유합니다.
- 오류 본문을 라우트마다 다른 모양으로 만들지 않습니다. `ApiError` 하나만 사용합니다.
- 저장소 경로, SQL, 스택 추적을 응답 본문에 담지 않습니다.
