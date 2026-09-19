# core Architecture

## Boundaries

- 도메인 타입은 전송 형식과 저장 형식을 알지 못합니다. 직렬화는 어댑터가 소유합니다.
- 저장 인터페이스 `TodoRepository`는 이 패키지가 소유하고 어댑터가 구현합니다. 의존 방향을 뒤집는 지점입니다.
- 시각은 포트가 아니라 인자입니다. 유스케이스는 `UTCTime`을 받아서 사용합니다.
- 조회 조건과 정렬은 `Todo.Core.Filter` 한 곳에서만 평가합니다. 저장소가 조건을 자체 구현하면 표면마다 결과가 달라집니다.

## Layers

```text
Todo.Core.UseCase        유스케이스 조합
      |
      +--> Todo.Core.Repository   저장 포트 (어댑터가 구현)
      +--> Todo.Core.Filter       조회 의미
      +--> Todo.Core.Status       상태 기계
      +--> Todo.Core.Validation   값 객체 생성
                |
                v
          Todo.Core.Types         도메인 어휘
```

## Verification

의존 방향과 순수성은 `../../../scripts/quality/architecture-check.sh`가 검사합니다. 규칙의 근거는 `../../../ARCHITECTURE.md`와 `../../../docs/decisions/ADR-0002-effect-boundary.md`에 있습니다.
