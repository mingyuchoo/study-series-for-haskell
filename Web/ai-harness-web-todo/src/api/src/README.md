# api Source

HTTP 어댑터 라이브러리입니다. 실행 파일 진입점은 `../app/Main.hs`이며 환경 변수를 읽어 warp을 띄우는 일만 합니다.

모듈별 책임은 `../README.md`, 오류 매핑은 `../docs/architecture.md`에 있습니다.

## 배치 규칙

- 라우트는 `Todo.Api.Routes`의 타입에만 정의합니다. 이 파일은 `../../../docs/generated/route-map.md`의 생성 원본입니다.
- 전송 표현은 `Todo.Api.Types`에 두고 JSON 인스턴스를 파생하지 않고 손으로 씁니다. 이유는 `../../../docs/decisions/ADR-0003-api-boundary.md`에 있습니다.
- 핸들러는 유스케이스를 호출하고 오류를 옮기기만 합니다.
- 오류 본문은 `ApiError` 하나만 사용합니다.
