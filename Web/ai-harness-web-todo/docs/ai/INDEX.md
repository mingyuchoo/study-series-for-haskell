# AI Context Index

이 문서는 모든 사람과 AI 에이전트가 Canonical Context를 탐색하는 시작점입니다. 전체 문서를 한꺼번에 읽지 말고 현재 작업에 관련된 경로를 선택합니다.

## 1. 프로젝트

- 프로젝트 소개: `../../README.md`
- 전체 아키텍처: `../../ARCHITECTURE.md`

## 2. 제품

- 제품 문서 지도: `../product/INDEX.md`
- 제품 비전: `../product/vision.md`
- 제품 불변조건: `../product/invariants.md`
- 용어: `../product/terminology.md`

## 3. 도메인

- 도메인 지도: `../domain/INDEX.md`
- 할 일: `../domain/task.md`
- 목록: `../domain/tasklist.md`
- 태그: `../domain/tag.md`
- 일정: `../domain/scheduling.md`

## 4. Architecture Decisions

- ADR 지도: `../decisions/INDEX.md`
- ADR 템플릿: `../decisions/ADR-TEMPLATE.md`

저장 기술, 효과 경계, HTTP 경계와 관련된 변경은 구현 전에 관련 ADR을 확인합니다.

## 5. Contracts

- 계약 지도: `../contracts/INDEX.md`
- API 계약: `../contracts/api/`
- 이벤트 계약: `../contracts/events/`
- 데이터 계약: `../contracts/data/`

## 6. 운영 경험

- 사고 기록 지도: `../incidents/INDEX.md`
- 반복 가능한 교훈: `../incidents/lessons.md`
- 패키지별 실패 방식: `../../src/`

## 7. 기술 부채

- 기술 부채 지도: `../tech-debt/INDEX.md`
- 활성 기술 부채: `../tech-debt/active.md`
- 해결된 기술 부채: `../tech-debt/resolved.md`

새 우회책을 추가하기 전에 기존 기술 부채를 확인합니다.

## 8. Machine-generated Facts

- DB 스키마: `../generated/db-schema.md`
- API 인덱스: `../generated/api-index.md`
- 라우트 지도: `../generated/route-map.md`
- 의존 그래프: `../generated/dependency-graph.md`
- 패키지 지도: `../generated/service-map.md`

생성 문서를 직접 수정하지 않고 대응하는 생성기를 수정합니다. 각 생성기의 원본은 다음과 같습니다.

| 생성 문서 | 원본 |
|---|---|
| DB 스키마 | `../../src/store/schema/schema.sql` |
| API 인덱스 | `../contracts/api/` |
| 라우트 지도 | `../../src/api/src/Todo/Api/Routes.hs` |
| 의존 그래프, 패키지 지도 | `../../src/` 아래 각 cabal 파일 |

## 9. 실행 계획

- 활성 계획: `../plans/active/`
- 완료 계획: `../plans/completed/`
- 계획 템플릿: `../plans/templates/PLAN-TEMPLATE.md`

## 10. AI 작업 정책

- 컨텍스트 정책: `CONTEXT_POLICY.md`
- 컨텍스트 수명 주기: `CONTEXT_LIFECYCLE.md`
- 컨텍스트 소유권: `OWNERSHIP.md`
- 작업 절차: `WORKFLOW.md`
- 영향 분석: `IMPACT_ANALYSIS.md`
- 완료 정의: `DEFINITION_OF_DONE.md`
- 정보 권위: `AUTHORITY.md`
- 위험 수준: `RISK_LEVELS.md`

## 검색 순서

1. 이 지도에서 관련 영역을 고릅니다.
2. 관련 영역의 `INDEX.md`를 읽습니다.
3. 현재 패키지의 `AGENTS.md` 또는 `CLAUDE.md`를 확인합니다.
4. 필요한 Canonical Source만 읽습니다.
5. 코드와 기계 검증 가능한 사실로 현재 상태를 확인합니다.
