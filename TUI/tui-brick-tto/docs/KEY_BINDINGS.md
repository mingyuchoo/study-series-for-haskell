# 키바인딩 설정 가이드

TUI Todo Manager의 키바인딩을 사용자 정의할 수 있습니다.

## 설정 파일 위치

`config/keybindings.yaml`

## 설정 방법

YAML 형식으로 각 액션에 대한 키를 설정할 수 있습니다. 각 액션은 여러 개의 키를 배열로 지정할 수 있습니다.

### 지원하는 특수 키

- `Enter` - 엔터 키
- `Esc` - ESC 키
- `Space` - 스페이스바
- `Up` - 위쪽 화살표
- `Down` - 아래쪽 화살표
- `Left` - 왼쪽 화살표
- `Right` - 오른쪽 화살표
- `Tab` - 탭 키
- `Backspace` - 백스페이스 키

### 일반 키

일반 문자 키는 작은따옴표로 감싸서 지정합니다: `'a'`, `'q'`, `'k'`, `'j'` 등

## 설정 가능한 액션

### quit
애플리케이션 종료
- 기본값: `['q', 'Esc']`

### add_todo
새 할 일 추가 모드로 전환
- 기본값: `['a']`

### toggle_complete
선택한 할 일의 완료 상태 토글
- 기본값: `['Space']`

### delete_todo
선택한 할 일 삭제
- 기본값: `['d']`

### navigate_up
목록에서 위로 이동
- 기본값: `['Up', 'k']`

### navigate_down
목록에서 아래로 이동
- 기본값: `['Down', 'j']`

### save_input
입력 모드에서 할 일 저장
- 기본값: `['Enter']`

### cancel_input
입력 모드에서 취소
- 기본값: `['Esc']`

## 설정 예시

```yaml
keybindings:
  quit: ['q', 'Esc']
  add_todo: ['a', 'n']  # 'a' 또는 'n' 키로 추가 가능
  toggle_complete: ['Space', 't']
  delete_todo: ['d', 'x']
  navigate_up: ['Up', 'k']
  navigate_down: ['Down', 'j']
  save_input: ['Enter']
  cancel_input: ['Esc']
```

## Vim 스타일 키바인딩 예시

```yaml
keybindings:
  quit: ['q']
  add_todo: ['i', 'a']
  toggle_complete: ['Space', 'x']
  delete_todo: ['d']
  navigate_up: ['k', 'Up']
  navigate_down: ['j', 'Down']
  save_input: ['Enter']
  cancel_input: ['Esc']
```

## 주의사항

- 설정 파일이 없거나 로드에 실패하면 기본 키바인딩이 사용됩니다.
- 잘못된 형식의 설정 파일은 무시되고 기본값이 사용됩니다.
- 애플리케이션 시작 시 설정이 로드되므로, 변경 사항을 적용하려면 애플리케이션을 재시작해야 합니다.
