# TUI Todo 애플리케이션 아키텍처

## 개요

TUI Todo는 Haskell로 작성된 터미널 기반 할일 관리 애플리케이션입니다. **Tagless Final** 패턴을 사용하여 effect를 추상화하고, 순수 함수와 효과를 명확히 분리한 구조를 가지고 있습니다.

## 프로젝트 구조

```
src/
├── Effects.hs                # Tagless Final Effect 타입클래스 정의
├── App.hs                    # Effect 인터프리터 (AppM 모나드)
├── TodoService.hs            # 비즈니스 로직 (Effect에만 의존)
├── TodoStatus.hs             # GADT 기반 상태 머신 (순수)
├── Config.hs                 # 설정 파일 로딩 (효과)
├── DB.hs                     # 데이터베이스 작업 (효과)
├── I18n.hs                   # 다국어 지원 (순수 + 효과)
├── Lib.hs                    # 애플리케이션 진입점
└── UI/
    ├── Types.hs              # 데이터 타입 정의 (순수)
    ├── Attributes.hs         # UI 스타일 정의 (순수)
    ├── Draw.hs               # UI 렌더링 (순수)
    └── Events.hs             # 이벤트 처리 (효과)
```

## Tagless Final 아키텍처

### Effect 타입클래스 (Effects.hs)

비즈니스 로직이 의존하는 추상 인터페이스를 정의합니다:

```haskell
-- Todo 저장소 작업
class Monad m => MonadTodoRepo m where
    getAllTodos :: m [DB.TodoRow]
    createTodo :: String -> m DB.TodoId
    createTodoWithFields :: String -> Maybe String -> Maybe String -> Maybe String -> m DB.TodoId
    updateTodoFields :: DB.TodoId -> String -> Maybe String -> Maybe String -> Maybe String -> m ()
    deleteTodo :: DB.TodoId -> m ()
    transitionToInProgress :: DB.TodoId -> m ()
    transitionToCancelled :: DB.TodoId -> m ()
    transitionToCompleted :: DB.TodoId -> m ()
    transitionToRegistered :: DB.TodoId -> m ()

-- 설정 접근
class Monad m => MonadConfig m where
    getKeyBindings :: m Config.KeyBindings

-- 다국어 메시지
class Monad m => MonadI18n m where
    getMessages :: m I18n.I18nMessages

-- 시간 연산
class Monad m => MonadTime m where
    getCurrentTime :: m UTCTime
```

### 인터프리터 (App.hs)

Effect 타입클래스의 구체적인 구현을 제공합니다:

```haskell
-- 애플리케이션 환경
data AppEnv = AppEnv
    { envConnection  :: !Connection
    , envMessages    :: !I18n.I18nMessages
    , envKeyBindings :: !Config.KeyBindings
    }

-- Tagless Final 인터프리터 모나드
newtype AppM a = AppM { unAppM :: ReaderT AppEnv IO a }

-- 각 Effect 타입클래스의 인스턴스 구현
instance MonadTodoRepo AppM where ...
instance MonadConfig AppM where ...
instance MonadI18n AppM where ...
instance MonadTime AppM where ...
```

### 비즈니스 로직 (TodoService.hs)

Effect 타입클래스에만 의존하는 순수한 비즈니스 로직:

```haskell
-- 모나드에 대해 다형적 - 테스트 용이
loadAllTodos :: MonadTodoRepo m => m [DB.TodoRow]
createNewTodo :: MonadTodoRepo m => String -> Maybe String -> Maybe String -> Maybe String -> m DB.TodoId
cycleStatusForward :: MonadTodoRepo m => DB.TodoId -> String -> m ()
findTodoById :: DB.TodoId -> [DB.TodoRow] -> Maybe DB.TodoRow  -- 순수 함수
```

## 모듈별 역할

### 순수(Pure) 모듈

#### TodoStatus.hs
GADT를 사용한 타입 안전 상태 머신:
- `TodoStatusType`: 타입 레벨 상태 태그 (Registered, InProgress, Cancelled, Completed)
- `TodoStatus`: GADT로 표현된 상태
- 상태 전환 함수: `startProgress`, `cancel`, `complete`
- 직렬화: `statusToString`, `stringToStatus`

#### UI/Types.hs
핵심 데이터 타입과 렌즈 정의:
- `Mode`: 애플리케이션 모드 (ViewMode, InputMode, EditMode)
- `Name`: 위젯 리소스 이름
- `FocusedField`: 포커스된 필드 추적
- `Todo`: UI Todo 항목 표현
- `AppState`: 애플리케이션 상태 (`appEnv` 포함)
- `fromTodoRow`: DB 행을 UI Todo로 변환

#### UI/Attributes.hs
UI 속성 및 스타일 정의:
- `theMap`: Vty 속성 맵
- 상태별 색상: registered(흰색), in_progress(노란색), cancelled(회색), completed(녹색)

#### UI/Draw.hs
UI 렌더링 로직 (순수 함수):
- `drawUI`: 메인 UI 그리기
- `drawHeader`: 헤더 렌더링
- `drawTodoList`: Todo 리스트 렌더링
- `drawTodo`: 개별 Todo 항목 렌더링
- `drawDetailView`: 상세 뷰 렌더링 (ViewMode, EditMode, InputMode)
- `drawHelp`: 도움말 렌더링
- `stringWidth`: 한글 등 멀티바이트 문자 너비 계산

#### I18n.hs (부분)
다국어 메시지 데이터 타입:
- `Language`: 지원 언어 (English, Korean)
- `I18nMessages`: 다국어 메시지 구조
- `defaultMessages`: 기본 영어 메시지

### 효과(Effect) 모듈

#### DB.hs
SQLite 데이터베이스 작업:
- `TodoRow`: 데이터베이스 Todo 표현 (status 기반)
- `initDB`, `initDBWithMessages`: 데이터베이스 초기화
- CRUD 함수들: `createTodo`, `getAllTodos`, `updateTodoWithFields`, `deleteTodo`
- 상태 전환: `transitionToInProgress`, `transitionToCancelled`, `transitionToCompleted`, `transitionToRegistered`

#### Config.hs
설정 파일 로딩:
- `KeyBindings`: 키바인딩 설정
- `KeyAction`: 키 액션 타입
- `loadKeyBindings`: YAML 파일에서 키바인딩 로드
- `matchesKey`, `matchesKeyWithMods`: 키 매칭 (순수)
- `getFirstKey`: 첫 번째 키 가져오기 (순수)

#### I18n.hs (부분)
다국어 파일 로딩:
- `loadMessages`: YAML 파일에서 메시지 로드 (IO)

#### UI/Events.hs
이벤트 처리 로직:
- `handleEvent`: 메인 이벤트 핸들러
- 모드별 이벤트 처리: `handleViewMode`, `handleInputMode`, `handleEditMode`
- TodoService를 통한 비즈니스 로직 호출
- 에디터 관리 함수들

#### Lib.hs
애플리케이션 진입점:
- `app`: Brick 애플리케이션 정의
- 모든 모듈 통합 및 re-export

## 데이터 흐름

```
┌─────────────────────────────────────────────────────────────────┐
│                        Main.hs                                   │
│  (AppEnv 생성, 초기 상태 설정, Brick 앱 실행)                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      UI/Events.hs                                │
│  (사용자 입력 처리, TodoService 호출)                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     TodoService.hs                               │
│  (비즈니스 로직, Effect 타입클래스에만 의존)                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        App.hs                                    │
│  (AppM 인터프리터, Effect 구현)                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         DB.hs                                    │
│  (SQLite 데이터베이스 작업)                                       │
└─────────────────────────────────────────────────────────────────┘
```

## Todo 상태 머신

```
┌────────────┐     ┌─────────────┐     ┌───────────┐     ┌───────────┐
│ Registered │ ──▶ │ InProgress  │ ──▶ │ Cancelled │ ──▶ │ Completed │
└────────────┘     └─────────────┘     └───────────┘     └───────────┘
      ▲                                                        │
      └────────────────────────────────────────────────────────┘
```

## 설계 원칙

1. **Tagless Final 패턴**: Effect를 타입클래스로 추상화하여 테스트 용이성 확보
2. **순수 함수와 효과 분리**: UI 렌더링은 순수, 데이터베이스 작업은 효과
3. **타입 안전성**: GADT를 사용한 상태 머신으로 잘못된 상태 전환 방지
4. **모듈화**: 역할별로 모듈 분리
5. **의존성 역전**: 비즈니스 로직이 구체적인 구현이 아닌 추상 인터페이스에 의존

## 확장 가이드

### 새로운 Effect 추가
1. `Effects.hs`에 새 타입클래스 정의
2. `App.hs`에 `AppM` 인스턴스 구현
3. `TodoService.hs`에서 새 Effect 사용

### 새로운 상태 추가
1. `TodoStatus.hs`의 `TodoStatusType`에 새 상태 추가
2. GADT 생성자 추가
3. 전환 함수 및 직렬화 함수 업데이트
4. `DB.hs`의 전환 함수 추가

### 테스트용 Mock 인터프리터 작성
```haskell
-- 테스트용 순수 인터프리터
newtype TestM a = TestM { runTestM :: State TestState a }

instance MonadTodoRepo TestM where
    getAllTodos = gets testTodos
    createTodo text = do
        modify $ \s -> s { testTodos = newTodo : testTodos s }
        pure newId
    -- ...
```

### 새로운 UI 컴포넌트 추가
`UI/` 디렉토리에 새 모듈 추가, `UI/Draw.hs`에서 호출

### 새로운 언어 추가
1. `I18n.hs`의 `Language` 타입에 추가
2. `config/messages-XX.yaml` 파일 생성
3. `loadMessages` 함수에 경로 추가
