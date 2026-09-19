# cli Architecture

## Boundaries

- `Todo.Cli.Options`는 문자열을 명령 구조로 바꾸기만 합니다. 비즈니스 규칙이 없습니다.
- `Todo.Cli.Render`는 순수 함수입니다. 출력 형식을 테스트할 수 있게 하기 위한 분리입니다.
- `Todo.Cli.Run`은 세 가지만 합니다. 값 검증, 시각 주입, 결과 출력과 종료 코드 결정.
- 실행 파일 `app/Main.hs`는 파서를 실행해 라이브러리에 넘기는 얇은 진입점입니다.

## Flow

```text
argv
  |
  v
Todo.Cli.Options      명령 구조
  |
  v
Todo.Cli.Run          검증과 시각 주입
  |
  +--> Todo.Core.Validation
  +--> Todo.Core.UseCase --> Todo.Store.Sqlite
  |
  v
Todo.Cli.Render       출력 문자열
```

## Exit Codes

| 코드 | 의미 |
|---|---|
| 0 | 요청을 처리했습니다. 상태가 바뀌지 않은 멱등 요청도 포함합니다 |
| 1 | 입력 검증 실패 또는 유스케이스 거부 |
| 2 | 명령줄 문법 오류. optparse-applicative가 반환합니다 |
