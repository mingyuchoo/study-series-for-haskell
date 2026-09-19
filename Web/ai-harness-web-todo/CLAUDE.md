# Project Memory

이 프로젝트에서는 단기적인 코드 생성 속도보다 장기적인 시스템 일관성을 우선합니다.
Haskell로 만든 로컬 우선 Todo List 앱이며, 규칙은 순수 도메인 패키지 한 곳에 모읍니다.

## Canonical Context

@docs/ai/INDEX.md
@ARCHITECTURE.md

## AI Workflow

@docs/ai/WORKFLOW.md
@docs/ai/IMPACT_ANALYSIS.md
@docs/ai/DEFINITION_OF_DONE.md
@docs/ai/AUTHORITY.md
@docs/ai/RISK_LEVELS.md

## Core Principles

- 현재 요청만 보고 국소적으로 최적화하지 않습니다.
- 기존 아키텍처와 도메인 불변조건을 먼저 확인합니다.
- 도메인 규칙은 `src/core`에 두고 CLI와 HTTP API에 복제하지 않습니다.
- `core`는 `IO`를 알지 못합니다. 부수 효과는 어댑터만 수행합니다.
- 새 기술이나 추상화를 추가하기 전에 기존 해결책을 검색합니다.
- 중요한 추론은 타입, 테스트 또는 계약으로 검증합니다.
- 장기적으로 유효한 새 지식은 저장소 컨텍스트로 공고화합니다.
