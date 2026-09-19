# Architecture Tests

의존 방향, 패키지 경계, 금지된 접근과 계층 규칙을 실행 가능하게 검증합니다.

실행 위치: `../../scripts/quality/architecture-check.sh`

## 다루는 것

- 각 패키지의 `build-depends`가 `../../ARCHITECTURE.md`가 허용한 방향만 갖는지
- `core`가 `IO`, 데이터베이스, 네트워크, 환경 변수 모듈을 import하지 않는지
- `cli`, `api`, `web`이 서로의 내부 모듈을 참조하지 않는지
- 각 패키지에 지역 컨텍스트 문서와 cabal 파일이 있는지

## Haskell 테스트 스위트가 아닌 이유

이 검사는 소스 파일과 빌드 설정을 정적으로 읽습니다. 빌드 없이 실행되므로 Haskell 툴체인 없는 CI 작업에서도 동작하고, 컴파일이 깨진 상태에서도 경계 위반을 알려줍니다.
