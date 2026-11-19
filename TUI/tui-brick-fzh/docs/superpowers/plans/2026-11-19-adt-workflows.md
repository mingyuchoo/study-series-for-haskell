# ADT Workflows Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 기존 TUI 동작을 보존하며 모든 작업 흐름을 순수 ADT 상태 머신과 효과 인터프리터로 분리한다.

**Architecture:** base 전용 도메인, 도메인을 사용하는 애플리케이션, 외부 I/O를 구현하는 터미널 패키지, apps 진입점으로 분리한다. 상태 전이는 명령을 반환하고 인터프리터가 결과 이벤트를 돌려준다.

**Tech Stack:** Haskell GHC2024, Stack, Hspec, Brick/Vty.

**Spec:** `docs/superpowers/specs/2026-11-19-adt-workflows-design.md`

## Global Constraints

- 새 소스 주석 없음. 도메인은 base만 의존. 패키지 간 상대 경로 import 없음.
- 기존 Emacs/Vim 키바인딩, 검색 정렬, 전체 화면과 현재 선택 출력 보존.
- 변경은 현재 작업 공간에서 수행하고 커밋/배포는 수행하지 않는다.

## Review Focus

- 빈 입력/검색 결과는 유효한 선택이나 미리보기 읽기를 만들지 않는다.
- 동일 경로의 이전 미리보기 응답도 요청 식별자로 구분한다.
- 완료 상태에서는 새 효과를 생성하지 않는다.
- 파일 시스템 실패는 보고하고 비동기 예외는 전파한다.
- Workspace 이동 후 Docker/CI/실행 및 배포 스크립트 경로가 유효하다.

### Task 1: 순수 도메인 상태 머신

**Files:** `packages/domain/src/Fzh/Domain/{Config,Search,Session,Discovery}.hs`, `packages/domain/test/Spec.hs`, `packages/domain/package.yaml`.

**Interfaces:** `transitionSession :: SessionEvent -> Session -> (Session, [SessionCommand])`, `transitionDiscovery :: DiscoveryEvent -> Discovery -> (Discovery, [DiscoveryCommand])`.

- [x] 검색, 세션 및 탐색의 전이/실패/경계 테스트를 먼저 작성하고 미구현 실패를 확인한다.
- [x] base 전용 도메인을 구현하고 독립적으로 테스트한다.

### Task 2: 애플리케이션 시작/종료 상태 머신과 포트

**Files:** `packages/application/src/Fzh/Application/{Workflow,Ports}.hs`, `packages/application/test/Spec.hs`, `packages/application/package.yaml`.

**Interfaces:** `transitionWorkflow :: WorkflowEvent -> Workflow -> (Workflow, [WorkflowCommand])`, `runWorkflow :: Monad m => WorkflowPorts m -> m Workflow`.

- [x] 빈 입력, 양쪽 입력 소스, 설정 기본값/경고, 오류/잘못된 이벤트, 포트 실행 테스트를 작성하고 실패를 확인한다.
- [x] 순수 워크플로와 추상 포트 실행기를 구현하고 테스트한다.

### Task 3: 터미널 어댑터 연결과 Workspace 전환

**Files:** 기존 `src`, `test` → `packages/terminal`, `app/Main.hs` → `apps/fzh/Main.hs`, `package.yaml`, `stack.yaml`, `cabal.project`, Docker/CI/scripts, README와 아키텍처 문서.

**Interfaces:** Vty 이벤트 → SessionEvent, SessionCommand → 파일 읽기/Brick 종료, WorkflowPorts IO → 구체적 I/O.

- [x] 모든 키바인딩 변환과 읽기 오류, 입력/설정/파일 탐색 어댑터의 통합 테스트를 작성한다.
- [x] 기존 API의 필요한 Text/Vector 변환은 어댑터에 유지하고 UI를 도메인 상태의 투영으로 변경한다.
- [x] 전체 `stack test --fast --test-arguments='+RTS -N2 -RTS'` 및 `stack build --pedantic --fast`를 실행한다.
- [x] 독립 검토, 전체 diff/경계/주석/스크립트 경로 검사 후 결과를 보고한다.
