# core Tests

상태 기계, 값 검증, 조회 의미, 유스케이스 멱등성을 검증합니다. 검증 대상 목록은 `../docs/invariants.md`에 있습니다.

```bash
cabal test core
```

## 규칙

- 외부 시스템을 쓰지 않습니다. 저장소는 `Todo.Core.Gen`과 `State` 기반 가짜 구현으로 대체합니다.
- 시각은 `Todo.Core.Gen.fixedNow`를 사용합니다. 실제 시계를 읽으면 테스트가 날짜에 따라 흔들립니다.
- 여기서 통과한 계약을 실제 저장소가 지키는지는 `../../store/tests`에서 확인합니다.
