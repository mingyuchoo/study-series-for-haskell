# core Context

이 디렉터리에서는 루트 지침과 함께 다음 Canonical Context를 확인합니다.

- `../../docs/domain/task.md`
- `../../docs/domain/tasklist.md`
- `../../docs/domain/tag.md`
- `../../docs/domain/scheduling.md`
- `../../docs/decisions/ADR-0002-effect-boundary.md`
- `./docs/invariants.md`
- `./docs/architecture.md`
- `./docs/failure-modes.md`

## Critical Areas

상태 기계, 값 객체의 검증 규칙, 조회 의미 변경은 CLI와 HTTP API의 동작을 동시에 바꿉니다. Level 2 이상으로 분석합니다.

## Do Not

- 이 패키지에 `IO`, 데이터베이스, 네트워크, 환경 변수 접근을 도입하지 않습니다. `scripts/quality/architecture-check.sh`가 이를 검사합니다.
- 현재 시각이나 오늘 날짜를 여기서 읽지 않습니다. 항상 인자로 받습니다.
- 부분 함수를 사용하지 않습니다. 실패는 `Either`로 표현합니다.

상세 불변조건을 이 파일에 복제하지 않고 `./docs/invariants.md`를 Canonical Source로 사용합니다.
