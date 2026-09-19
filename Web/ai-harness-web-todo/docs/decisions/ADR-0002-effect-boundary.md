# ADR-0002: 부수 효과 경계

- 상태: Accepted
- 날짜: 2026-08-22
- 결정자: Todo Maintainers
- 관련 이슈: 없음
- 대체 관계: 없음

## Context

도메인 규칙은 CLI와 HTTP API 두 표면이 공유해야 합니다(`../product/invariants.md`의 `PROD-INV-003`). 규칙이 어느 한 표면이나 저장 기술에 묶이면 다른 쪽에 복제되고, 복제된 순간부터 두 표면이 갈라지기 시작합니다.

Haskell에서 이 경계를 표현하는 방법은 여러 가지이며, 선택에 따라 테스트 방식과 학습 비용이 크게 달라집니다.

## Decision Drivers

- 도메인 규칙을 저장 기술과 전송 기술 없이 테스트할 수 있어야 합니다.
- 테스트가 시계나 파일 시스템에 의존하지 않고 결정적이어야 합니다.
- 경계 위반을 사람의 주의가 아니라 기계가 잡아야 합니다.
- 기여자가 배워야 할 개념 수가 적어야 합니다.

## Considered Options

1. 도메인이 소유하는 타입클래스 포트 + mtl 스타일 (`class Monad m => TodoRepository m`)
2. `effectful` 또는 `polysemy` 같은 효과 시스템
3. free monad 기반 인터프리터
4. 도메인 함수가 직접 `IO`를 수행

## Decision

`core`가 `TodoRepository` 타입클래스를 소유하고 어댑터가 인스턴스를 제공합니다. 유스케이스는 `TodoRepository m => ... -> m a` 형태로 다형입니다.

시각은 포트로 만들지 않습니다. 유스케이스가 `UTCTime`을 인자로 받고, 경계(CLI의 `Run`, API의 핸들러)에서 읽어 주입합니다.

`core`는 `IO`, 데이터베이스, 네트워크, 환경 변수 모듈을 import하지 않으며 이를 `scripts/quality/architecture-check.sh`가 검사합니다.

## Why

효과 시스템과 free monad는 표현력이 크지만, 이 규모의 앱에서 필요한 효과는 "할 일을 저장하고 읽는다" 하나뿐입니다. 인터프리터 계층과 효과 타입을 도입하면 기여자가 도메인 규칙을 읽기 전에 효과 라이브러리를 먼저 배워야 합니다. 얻는 것에 비해 비쌉니다.

도메인이 직접 `IO`를 하면 테스트가 파일 시스템에 의존하고, 무엇보다 도메인이 저장 기술을 알게 되어 `ADR-0001`을 되돌리기 어려워집니다.

시계를 포트로 만들지 않은 것은 별도의 판단입니다. 시각은 반환값이 필요할 뿐 상태가 없으므로, 포트를 만드는 대신 인자로 받으면 유스케이스가 완전한 순수 함수에 가까워집니다. 테스트에서 고정 시각을 넣기만 하면 되고 가짜 시계 구현이 필요 없습니다. 실제로 `core`의 유스케이스 테스트는 `State` 기반 가짜 저장소 하나만으로 동작합니다.

## Consequences

### Positive

- 유스케이스 테스트가 SQLite 없이 실행되고 결정적입니다.
- 같은 유스케이스를 CLI와 API가 그대로 호출하므로 규칙이 갈라질 수 없습니다.
- 저장 기술 교체가 어댑터 하나의 교체로 끝납니다.
- 경계 위반이 CI에서 실패합니다.

### Negative

- 타입클래스 하나에 저장 연산이 모두 모입니다. 연산이 늘면 인스턴스가 비대해집니다.
- 유스케이스 시그니처에 `UTCTime` 인자가 반복해 나타납니다.
- 어댑터가 `SqliteT` 같은 실행 모나드를 하나 더 갖게 됩니다.

### Risks and Mitigations

- 위험: 편의를 위해 `core`에 `MonadIO` 제약을 추가하고 싶어집니다. 완화: 아키텍처 검사가 `Control.Monad.IO.Class` import를 거부합니다.
- 위험: 포트가 커져 도메인이 저장 구조를 반영하게 됩니다. 완화: 포트 연산 추가 시 조회 의미를 `Todo.Core.Filter`에 두는지 먼저 확인합니다.

## Verification

- 순수성 검사: `scripts/quality/architecture-check.sh`
- 가짜 저장소 기반 유스케이스 테스트: `src/core/tests/Todo/Core/UseCaseSpec.hs`
- 같은 계약의 실제 구현 검증: `src/store/tests/Todo/Store/SqliteSpec.hs`

## Revisit Conditions

- 저장 외에 로깅, 알림, 외부 호출처럼 성격이 다른 효과가 두 개 이상 생길 때.
- 유스케이스가 여러 포트를 동시에 요구해 제약 목록이 길어질 때. 그때 효과 시스템을 다시 검토합니다.
