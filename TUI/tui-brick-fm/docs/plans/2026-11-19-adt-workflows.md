# ADT Workflow Implementation Plan

**Goal:** 모든 제품 작업 절차를 명시적인 ADT 상태 전이로 표현한다.

**Architecture:** Request의 응답 타입과 Phase의 입력 타입을 GADT로 연결한다. 순수 Machine.resume이 진행을 결정하고 Runtime은 주입된 포트만 실행한다.

**Tech Stack:** Haskell GHC2024, Stack, Hspec, Brick, 기존 워크스페이스.

**Spec:** [설계](2026-11-19-adt-workflows-design.md)

## Global Constraints

- 기존 키, 화면, 플랫폼 경로 정책을 유지한다.
- 순수 모듈에 효과 실행, 외부 프레임워크 의존성 및 소스 주석을 추가하지 않는다.
- 새 외부 의존성을 추가하지 않는다.
- 현재 체크아웃에서 변경하고 자동 커밋하지 않는다.

## Review Focus

- 설정 저장 실패 시 입력 및 테마 미리보기 복원.
- 각 시작 단계 실패 후 다음 요청 중단.
- 두 번째 패널 읽기 실패 시 두 패널 모두 보존.
- 파일 변경 성공 후 목록 갱신 실패 시 완료된 파일 작업 재실행 방지.
- 모달 및 테마 미리보기 중 전역 키와 접두 명령 유지.

## Task 1: 타입이 정해진 작업 단계

Files: Program.hs, Machine.hs, Startup.hs, application/test/Spec.hs.

Interfaces: Program a, Request response, Phase response a, resume :: Phase response a -> Either FileError response -> Program a.

- [x] 설정 변경이 저장 응답을 기다리는 실패 테스트를 작성하고 실행한다.
- [x] 시작 및 작업 진행 단계, KeySequence, Lifecycle ADT를 정의한다.
- [x] 순수 resume과 단계별 실패/성공 전이를 구현한다.

## Task 2: 입력과 실행기 이전

Files: Workflow.hs, Internal/Files.hs, Internal/Interaction.hs, Internal/Process.hs, Effects/Runtime.hs, State.hs, Tui/Event.hs, Tui/Layout.hs, Tui/UI.hs, 앱 Main.hs, package.yaml.

Interfaces: planInput :: Input -> AppState -> Program (AppState, Lifecycle); runProgram은 설정 저장 포트도 받는다.

- [x] 모나드 상태 조합을 직접적인 순수 입력 함수 및 ADT 단계 생성으로 교체한다.
- [x] 설정 저장 정책을 순수 전이로 옮기고 실행기에서 상태 비교를 제거한다.
- [x] UI, 앱, 기존 테스트 호출자를 새 ADT 및 resume API로 변경한다.
- [x] 불필요한 Internal.Action 및 production mtl/transformers 의존성을 제거한다.
- [x] application 테스트를 실행한다. Expected: 0 failures.

## Task 3: 실패 경계, 문서 및 전체 검증

Files: application/test/Spec.hs, tui/test/Spec.hs, docs/ARCHITECTURE.md.

- [x] Review Focus 및 모든 효과 분기의 성공/실패를 순수 전이 또는 메모리 포트 테스트로 검증한다.
- [x] 아키텍처 문서를 ADT 및 새 API 기준으로 갱신한다.
- [x] stack test --fast --ghc-options='-Werror -Wincomplete-patterns'를 실행한다. Expected: 모든 suite 통과.
- [x] stack run hfm-check-architecture 및 PTY 키 바인딩 검증을 실행한다. Expected: 통과.
- [x] 독립 코드 리뷰 후 발견 사항을 해결하고 필요한 검증을 다시 실행한다.

## Verification Results

- 설정 저장 대기 회귀 테스트: 기존 코드에서 실패를 확인한 뒤 상태 머신 구현에서 통과.
- `stack test --fast --ghc-options='-Werror -Wincomplete-patterns'`: 131 examples, 0 failures (application 53, domain 12, infrastructure 21, tui 26, dev-tools 19).
- `stack run hfm-check-architecture`: 통과.
- `stack exec hfm-test-keybindings -- "$(stack path --local-install-root)/bin/hfm"`: 실제 터미널 키·파일 작업·외부 프로그램·설정·여덟 테마·모달 종료 검증 통과.
- 독립 코드 리뷰: 지적 사항 없음.
- `git diff --check`: 통과.
