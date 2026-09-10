task_id: T-2026-0911-025
from: orchestrator
status: REVIEW
summary: "새 업무 등록과 업무 수정을 우측 서랍형 패널로 전환했다."
assumptions:
  - "새 업무 등록의 진입점은 업무 보드 상단에 둔다."
result: |
  - web/src/Application/TaskBoard.elm: 서랍 열기·닫기 상태와 메시지를 추가했다.
  - web/src/Presentation/TaskBoard.elm: 상시 생성 폼을 제거하고 우측 서랍으로 렌더링했다.
  - web/styles.css: 상세 패널과 일관된 서랍 및 반응형 스타일을 추가했다.
  - web/styles.css: 등록 서랍 내부 카드의 테두리·둥근 모서리·그림자를 제거했다.
  - web/styles.css: 등록 서랍의 우선순위 입력 열을 같은 폭으로 맞춰 중요도 라디오 버튼이 한 줄에 표시되도록 했다.
  - web/tests/MainTest.elm: 서랍 열기·닫기 상태 초기화 테스트를 추가했다.
sources:
  - path: docs/UX.md
    note: "화면 인터랙션 기준"
open_questions: []
risks:
  - "elm-format 실행 파일은 로컬 node_modules에 없어 포맷 명령은 실행하지 못했다."
cost:
  tokens: 0
  tool_calls: 0
