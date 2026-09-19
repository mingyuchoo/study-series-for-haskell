## 목적

이 변경이 해결하는 사용자 또는 시스템 문제를 설명하십시오.

## 변경 내용

- 핵심 변경 사항

## 위험 수준

`docs/ai/RISK_LEVELS.md` 기준: Level __

## 영향 분석

- 도메인 불변조건:
- 패키지와 의존 방향:
- SQLite 스키마와 기존 데이터:
- API 계약:
- CLI 명령과 출력 형식:
- 보안 전제와 입력 검증:
- 운영과 롤백:

## 검증

- [ ] 단위 테스트 (`src/core/tests`)
- [ ] 통합 테스트 (`src/store/tests`)
- [ ] 계약 테스트 (`src/api/tests`)
- [ ] 보안 테스트 (`src/api/tests`)
- [ ] 회귀 테스트 (`src/store/tests`)
- [ ] 아키텍처 검사 (`scripts/quality/architecture-check.sh`)
- [ ] 무경고 빌드와 형식 검사 (`scripts/quality/lint.sh`)
- [ ] 컨텍스트 무결성 검사 (`scripts/context/validate-context.sh`)

실행하지 않은 항목은 이유와 잔여 위험을 작성하십시오.

## Context Consolidation

- [ ] 아키텍처 또는 도메인 문서를 갱신했습니다.
- [ ] 계약 문서를 갱신했습니다.
- [ ] 생성 문서의 원본을 바꿨다면 해당 생성기를 실행했습니다.
- [ ] 장기 결정이 있으면 ADR을 작성했습니다.
- [ ] 반복 가능한 교훈을 테스트, 규칙 또는 문서로 승격했습니다.
- [ ] 해당 사항이 없으며 이유를 설명했습니다.
