# Repository Agent Instructions

## Mission

이 저장소에서는 단기적인 구현 속도보다 장기적인 시스템 일관성을 우선합니다.
국소적으로 올바른 변경이 전체 시스템의 경계와 불변조건을 훼손하지 않게 합니다.

## Canonical Context

작업 전 다음 문서부터 확인합니다.

- `docs/ai/INDEX.md`
- `ARCHITECTURE.md`

상세 지식을 이 파일에 복제하지 않고 Canonical Context를 참조합니다.
하위 디렉터리에 `AGENTS.md`가 있으면 해당 범위에서는 그 지침을 함께 적용합니다.

## Project Shape

Haskell 다중 패키지 cabal 프로젝트입니다. 의존 방향은 한 방향입니다.

```text
cli, api, web --> store --> core
```

- `src/core`는 순수 도메인입니다. `IO`를 알지 못합니다.
- 규칙은 `core`에 두고 CLI와 HTTP API에 복제하지 않습니다.
- 저장은 SQLite이며 스키마 원본은 `src/store/schema/schema.sql` 하나입니다.

## Required Workflow

코드를 수정하기 전에 다음을 수행합니다.

1. 요청의 실제 목적을 파악합니다.
2. 관련 코드, 문서, 계약을 검색합니다.
3. 관련 ADR과 과거 사고 기록을 확인합니다.
4. `docs/ai/IMPACT_ANALYSIS.md`에 따라 영향 범위를 분석합니다.
5. 기존 구현과 패턴의 재사용 가능성을 확인합니다.
6. 위험 수준에 맞는 변경 계획을 세웁니다.

구현 후 다음을 수행합니다.

1. 관련 테스트와 정적 검사를 실행합니다.
2. 계약과 아키텍처 규칙을 확인합니다.
3. 생성 문서의 원본을 바꿨다면 해당 생성기를 실행합니다.
4. 회귀 가능성과 운영 영향을 확인합니다.
5. 장기적으로 유효한 새 지식을 ADR, 문서, 계약 또는 테스트로 공고화합니다.
6. `docs/ai/DEFINITION_OF_DONE.md`를 확인합니다.

## Do Not

- `core`에 `IO`, 데이터베이스, 네트워크, 환경 변수 접근을 도입하지 않습니다.
- 도메인 타입에 JSON이나 SQL 인스턴스를 붙이지 않습니다. 전송과 저장 표현은 어댑터가 따로 소유합니다.
- 조회 조건이나 상태 전이를 SQL이나 핸들러에서 다시 구현하지 않습니다.
- 부분 함수를 사용하지 않습니다. 실패는 `Either`로 표현합니다.
- `docs/generated` 아래 문서를 직접 편집하지 않습니다.
- 기존 패턴을 확인하지 않고 새 추상화나 의존성을 추가하지 않습니다.
- 문서와 코드가 충돌하면 추측하지 않습니다. `docs/ai/AUTHORITY.md`를 따릅니다.
- 임시 우회책을 영구 아키텍처로 취급하지 않습니다.
- 작업 중간의 추측과 대화 기록을 Canonical Fact로 저장하지 않습니다.

## Validation

최종 변경 전에 가능한 범위에서 다음을 실행합니다.

```bash
./scripts/quality/lint.sh
./scripts/quality/test.sh
./scripts/quality/architecture-check.sh
./scripts/context/validate-context.sh
```

구체적인 절차는 `docs/ai/WORKFLOW.md`를 따릅니다.
