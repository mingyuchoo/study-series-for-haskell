# tto

터미널 기반 할 일 관리 애플리케이션 (Brick + SQLite + Tagless Final 패턴)

## How to create a project

```bash
stack new <project-name> mingyuchoo/cli
```

## How to build

```bash
stack build
# or
stack build --fast --file-watch --ghc-options "-j4 +RTS -A128m -n2m -RTS"
```

## How to test as watch mode

```bash
stack test --fast --file-watch --watch-all
# or
stack test --coverage --fast --file-watch --watch-all --haddock
# or
ghcid --command "stack ghci test/Spec.hs"
```

## How to run

```bash
stack run
```
You can also use `Makefile` for these works.

## 아키텍처

### 모듈 구조

- **TodoStatus**: GADT 기반 타입 안전한 상태 머신 (`Registered → InProgress → Cancelled → Completed → Registered`)
- **Effects**: Tagless Final 효과 대수 (`MonadTodoRepo`, `MonadConfig`, `MonadI18n`, `MonadTime`)
- **App**: Tagless Final 해석기 (ReaderT + IO)
- **TodoService**: 순수 비즈니스 로직 (입력 검증, 타입 안전한 상태 전이 디스패치)
- **DB**: SQLite 데이터베이스 연산
- **UI.Types**: UI 데이터 타입 및 렌즈
- **UI.Draw**: 순수 렌더링 함수 (상태 헬퍼 함수로 중복 제거)
- **UI.Events**: 이벤트 핸들러 (에러 피드백 메커니즘 포함)
- **UI.Attributes**: 터미널 UI 속성 정의
- **Config**: YAML 기반 키바인딩 설정
- **I18n**: 다국어 지원 (한국어/영어)

### 주요 설계 원칙

- **타입 안전성**: GADT를 통한 컴파일 타임 상태 전이 검증, `AnyStatus` 패턴 매칭을 통한 런타임 디스패치
- **효과 분리**: Tagless Final 패턴으로 순수 비즈니스 로직과 IO 분리
- **에러 피드백**: DB 작업 실패 시 UI에 에러 메시지 표시 (조용한 실패 방지)
- **입력 검증**: `createNewTodo`에서 빈 action 검증 (`Maybe TodoId` 반환)

## 키바인딩 설정

TUI Todo Manager는 사용자 정의 키바인딩을 지원합니다.

### 설정 파일

키바인딩 설정은 `config/keybindings.yaml` 파일에서 관리됩니다.

### 기본 키바인딩

- `q` 또는 `Esc`: 애플리케이션 종료
- `a`: 새 할 일 추가
- `e`: 할 일 편집
- `Space`: 할 일 상태 순환 토글
- `d`: 할 일 삭제
- `↑` 또는 `k`: 위로 이동
- `↓` 또는 `j`: 아래로 이동

### 키바인딩 커스터마이징

`config/keybindings.yaml` 파일을 수정하여 원하는 키를 설정할 수 있습니다.

예시 - Vim 스타일 키바인딩:
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

자세한 설정 방법은 `config/README.md`를 참조하세요.

### 예시 설정 파일

- `config/keybindings.yaml`: 기본 키바인딩
- `config/keybindings-vim.yaml`: Vim 스타일 키바인딩 예시
