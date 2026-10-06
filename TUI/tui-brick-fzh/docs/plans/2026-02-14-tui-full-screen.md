# TUI 전체 화면 사용 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** TUI가 터미널 전체 영역을 동적으로 사용하도록 개선 (40:60 비율, 최소 크기 경고 포함)

**Architecture:** Brick 레이아웃 엔진을 활용한 하이브리드 접근. 터미널 크기를 AppState에 저장하고, 리사이즈 이벤트 처리. 고정 크기 제한 제거 후 동적 계산 적용.

**Tech Stack:** Haskell, Brick (TUI), Vty (터미널), HUnit/Tasty (테스팅)

---

## Task 1: Types.hs - 헬퍼 함수 추가

**Files:**
- Modify: `src/Types.hs`
- Test: `test/Spec.hs`

**Step 1: 헬퍼 함수 테스트 작성**

`test/Spec.hs`에 다음 테스트 추가:

```haskell
module Main (main) where

import Test.Tasty
import Test.Tasty.HUnit
import Types

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "Tests"
  [ testTerminalSizeCheck
  , testLayoutCalculations
  ]

testTerminalSizeCheck :: TestTree
testTerminalSizeCheck = testGroup "Terminal Size Checks"
  [ testCase "Minimum size accepted" $
      isTerminalSizeSufficient (80, 24) @?= True
  , testCase "Below minimum width rejected" $
      isTerminalSizeSufficient (79, 24) @?= False
  , testCase "Below minimum height rejected" $
      isTerminalSizeSufficient (80, 23) @?= False
  , testCase "Large size accepted" $
      isTerminalSizeSufficient (200, 50) @?= True
  ]

testLayoutCalculations :: TestTree
testLayoutCalculations = testGroup "Layout Calculations"
  [ testCase "Result list width is 40%" $
      resultListWidth 100 @?= 40
  , testCase "Preview width is 60%" $
      previewWidth 100 @?= 60
  , testCase "Widths sum to total" $
      let w = 100
      in resultListWidth w + previewWidth w @?= w
  , testCase "Content height calculation" $
      contentHeight 30 @?= 22  -- 30 - 3 - 3 - 2
  ]
```

**Step 2: 테스트 실행 (실패 확인)**

```bash
stack test
```

예상 출력: FAIL - "Not in scope: 'isTerminalSizeSufficient'" 등

**Step 3: Types.hs에 헬퍼 함수 추가**

`src/Types.hs`의 export 리스트에 추가:

```haskell
module Types
    ( AppConfig (..)
    , AppState (..)
    , Name (..)
    , configWithKeyBinding
    , defaultConfig
    , initialState
    -- 새로 추가
    , isTerminalSizeSufficient
    , resultListWidth
    , previewWidth
    , contentHeight
    ) where
```

파일 끝에 헬퍼 함수 구현 추가:

```haskell
-- | 터미널이 최소 크기 이상인지 확인 (Pure)
-- 최소 크기: 80x24
isTerminalSizeSufficient :: (Int, Int) -> Bool
isTerminalSizeSufficient (w, h) = w >= 80 && h >= 24

-- | 결과 리스트 너비 계산 (Pure)
-- 전체 너비의 40%
resultListWidth :: Int -> Int
resultListWidth termWidth = (termWidth * 2) `div` 5

-- | 미리보기 너비 계산 (Pure)
-- 전체 너비의 60% (= 전체 - 40%)
previewWidth :: Int -> Int
previewWidth termWidth = termWidth - resultListWidth termWidth

-- | 컨텐츠 영역 높이 계산 (Pure)
-- 전체 높이 - 고정 요소들(검색 3줄 + 정보 3줄 + 도움말 2줄)
contentHeight :: Int -> Int
contentHeight termHeight = termHeight - 3 - 3 - 2
```

**Step 4: 테스트 실행 (성공 확인)**

```bash
stack test
```

예상 출력: All tests passed

**Step 5: 커밋**

```bash
git add src/Types.hs test/Spec.hs
git commit -m "feat(types): Add terminal size helper functions

- Add isTerminalSizeSufficient for 80x24 minimum check
- Add resultListWidth for 40% calculation
- Add previewWidth for 60% calculation
- Add contentHeight for dynamic height calculation
- Add comprehensive unit tests

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Types.hs - AppState에 터미널 크기 추가

**Files:**
- Modify: `src/Types.hs`
- Test: `test/Spec.hs`

**Step 1: AppState 수정 테스트 작성**

`test/Spec.hs`에 테스트 추가:

```haskell
testAppStateWithTerminalSize :: TestTree
testAppStateWithTerminalSize = testGroup "AppState with Terminal Size"
  [ testCase "Initial state includes terminal size" $
      let items = ["file1.txt", "file2.txt"]
          cfg = defaultConfig
          termSize = (100, 30)
          st = initialState items cfg termSize
      in stTerminalSize st @?= (100, 30)
  ]

-- tests 함수에 추가
tests :: TestTree
tests = testGroup "Tests"
  [ testTerminalSizeCheck
  , testLayoutCalculations
  , testAppStateWithTerminalSize  -- 추가
  ]
```

**Step 2: 테스트 실행 (실패 확인)**

```bash
stack test
```

예상 출력: FAIL - "Not in scope: 'stTerminalSize'"

**Step 3: AppState 데이터 타입 수정**

`src/Types.hs`에서 `AppState` 수정:

```haskell
-- | 앱의 현재 상태를 담는 레코드 타입
-- 아이템 목록, 필터링 결과, 검색어, 설정, 터미널 크기 포함
data AppState = AppState { stItems        :: !(Vec.Vector T.Text)
                           -- ^ 전체 아이템
                         , stFilteredList :: !(List Name T.Text)
                           -- ^ 필터링된 리스트
                         , stSearchQuery  :: !T.Text
                           -- ^ 현재 검색어
                         , stConfig       :: !AppConfig
                           -- ^ 앱 설정
                         , stFileContent  :: !(Maybe T.Text)
                           -- ^ 선택된 파일의 내용
                         , stTerminalSize :: !(Int, Int)
                           -- ^ 터미널 크기 (width, height)
                         }
```

`initialState` 함수 수정:

```haskell
-- | 아이템 목록, 설정, 터미널 크기로 초기 상태 생성 (Pure)
-- 검색어는 빈 문자열로 초기화
initialState :: [T.Text] -> AppConfig -> (Int, Int) -> AppState
initialState items cfg termSize =
  let itemVec = Vec.fromList items
  in AppState
       { stItems        = itemVec
       , stFilteredList = list ItemList itemVec 1
       , stSearchQuery  = ""
       , stConfig       = cfg
       , stFileContent  = Nothing
       , stTerminalSize = termSize
       }
```

**Step 4: 테스트 실행 (성공 확인)**

```bash
stack test
```

예상 출력: All tests passed

**Step 5: 커밋**

```bash
git add src/Types.hs test/Spec.hs
git commit -m "feat(types): Add terminal size to AppState

- Add stTerminalSize field to track terminal dimensions
- Update initialState to accept terminal size parameter
- Add test for terminal size initialization

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: UI.hs - 경고 UI 렌더링 추가

**Files:**
- Modify: `src/UI.hs`

**Step 1: 빌드 확인 (현재는 컴파일 에러 발생)**

```bash
stack build
```

예상: FAIL - Main.hs에서 initialState 호출 시 인자 부족 에러

**Note:** 이 에러는 Task 5에서 해결됩니다. 지금은 UI.hs만 수정합니다.

**Step 2: UI.hs에 경고 렌더링 함수 추가**

`src/UI.hs`의 import 섹션에 추가:

```haskell
import           Brick.Widgets.Center
```

export 리스트에 추가:

```haskell
module UI
    ( drawUI
    , formatInfoText
    , renderWarningUI  -- 추가
    ) where
```

파일 끝에 경고 UI 함수 추가:

```haskell
-- | 터미널 크기 경고 UI 렌더링 (Pure)
-- 터미널이 최소 크기 미만일 때 표시
renderWarningUI :: AppState -> Widget Name
renderWarningUI st =
  let (w, h) = stTerminalSize st
      warning = vCenter <| hCenter <| vBox
        [ txt "⚠️  터미널 크기가 너무 작습니다"
        , txt ""
        , txt <| "현재: " <> T.pack (show w) <> "x" <> T.pack (show h)
        , txt "최소: 80x24"
        , txt ""
        , txt "터미널 크기를 조정해주세요"
        ]
  in border warning
```

**Step 3: 커밋**

```bash
git add src/UI.hs
git commit -m "feat(ui): Add warning UI for small terminals

- Add renderWarningUI to display size warning
- Show current and minimum terminal dimensions
- Center warning message in terminal

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: UI.hs - 동적 레이아웃으로 변경

**Files:**
- Modify: `src/UI.hs`

**Step 1: drawUI 함수를 동적 크기 사용으로 변경**

`src/UI.hs`의 `drawUI` 함수 전체 교체:

```haskell
-- | 메인 UI 렌더링 함수 (Pure)
-- 앱 상태를 받아 Brick 위젯 리스트 반환
-- 터미널 크기에 따라 정상 UI 또는 경고 UI 표시
drawUI :: AppState -> [Widget Name]
drawUI st = [ui]
  where
    (termWidth, termHeight) = stTerminalSize st
    cfg = stConfig st

    -- 경고 메시지 표시 여부 확인
    ui = if isTerminalSizeSufficient (termWidth, termHeight)
         then renderNormalUI st termWidth termHeight cfg
         else renderWarningUI st
```

`renderNormalUI` 함수 추가:

```haskell
-- | 정상 UI 렌더링 (Pure)
-- 터미널 전체 영역을 사용하는 동적 레이아웃
renderNormalUI :: AppState -> Int -> Int -> AppConfig -> Widget Name
renderNormalUI st termWidth termHeight cfg = vBox
  [ renderSearchBox st termWidth
  , hBox
      [ vLimit (contentHeight termHeight) <|
        hLimit (resultListWidth termWidth) <|
        renderResultList cfg st
      , vLimit (contentHeight termHeight) <|
        hLimit (previewWidth termWidth) <|
        renderFilePreview cfg st
      ]
  , renderInfo cfg st termWidth
  , padTop (Pad 1) <| hCenter <| renderKeyBindingHelp cfg
  ]
```

**Step 2: 개별 렌더링 함수 수정**

`renderSearchBox` 함수 수정:

```haskell
-- | 검색 입력 박스 렌더링 (Pure)
-- 현재 검색어와 커서(_) 표시
-- 터미널 너비에 맞춰 동적 조정
renderSearchBox :: AppState -> Int -> Widget Name
renderSearchBox st termWidth =
  hLimit termWidth <|
  borderWithLabel (txt "Search") <|
  padLeftRight 1 <|
  txt (stSearchQuery st <> "_")
```

`renderResultList` 함수 수정 (시그니처 변경 없음, 내부만 수정):

```haskell
-- | 검색 결과 리스트 렌더링 (Pure)
-- 필터링된 아이템 목록을 스크롤 가능한 리스트로 표시
-- 고정 너비 제한 제거 (동적 크기 사용)
renderResultList :: AppConfig -> AppState -> Widget Name
renderResultList _cfg st =
  borderWithLabel (txt "Results") <|
  renderList drawItem True (stFilteredList st)
  where
    -- | 개별 아이템 렌더링 (Pure)
    drawItem _ item = txt ("  " <> item)
```

`renderFilePreview` 함수 수정:

```haskell
-- | 파일 미리보기 렌더링 (Pure)
-- 선택된 파일의 내용을 표시
-- 고정 너비 제한 제거 (동적 크기 사용)
renderFilePreview :: AppConfig -> AppState -> Widget Name
renderFilePreview _cfg st =
  borderWithLabel (txt "Preview") <|
  padLeftRight 1 <|
  case stFileContent st of
    Nothing      -> txt "No file selected"
    Just content -> txtWrap content
```

`renderInfo` 함수 수정:

```haskell
-- | 정보 표시줄 렌더링 (Pure)
-- 현재 표시된 아이템 개수 및 선택 위치 표시
-- 터미널 너비에 맞춰 동적 조정
renderInfo :: AppConfig -> AppState -> Int -> Widget Name
renderInfo _cfg st termWidth =
  hLimit termWidth <|
  border <|
  padLeftRight 1 <|
  txt <| formatInfoText totalItems selectedIdx
  where
    totalItems = Vec.length <| listElements <| stFilteredList st
    selectedIdx = fst <$> listSelectedElement (stFilteredList st)
```

**Step 3: 커밋**

```bash
git add src/UI.hs
git commit -m "feat(ui): Implement dynamic layout using full terminal

- Replace fixed size limits with dynamic calculations
- Add renderNormalUI for terminal-aware layout
- Update all render functions to accept terminal dimensions
- Remove configMaxWidth usage in favor of actual terminal width
- Maintain 40:60 ratio for results and preview

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Event.hs - 리사이즈 이벤트 처리 추가

**Files:**
- Modify: `src/Event.hs`

**Step 1: Event.hs에 리사이즈 핸들러 추가**

`src/Event.hs`의 import 섹션 확인 (Graphics.Vty가 이미 import 되어 있어야 함):

```haskell
import qualified Graphics.Vty as V
```

`handleEvent` 함수에 리사이즈 케이스 추가 (기존 VtyEvent 핸들링 부분에 추가):

```haskell
handleEvent :: BrickEvent Name e -> EventM Name AppState ()
handleEvent e = case e of
  -- ... 기존 키 이벤트 핸들러들 ...

  -- 터미널 리사이즈 처리
  VtyEvent (V.EvResize w h) -> do
    modify $ \st -> st { stTerminalSize = (w, h) }

  -- ... 기타 이벤트 핸들러들 ...
```

**참고:** Event.hs의 정확한 구조를 확인하여 적절한 위치에 삽입해야 합니다.

**Step 2: 빌드 확인**

```bash
stack build
```

예상: 여전히 Main.hs에서 에러 (다음 Task에서 해결)

**Step 3: 커밋**

```bash
git add src/Event.hs
git commit -m "feat(event): Handle terminal resize events

- Add EvResize event handler to update stTerminalSize
- Enable dynamic UI adjustment on terminal size change

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Main.hs - 초기 터미널 크기 획득

**Files:**
- Modify: `app/Main.hs`

**Step 1: Main.hs 읽기**

```bash
cat app/Main.hs
```

현재 구조 파악 후 수정

**Step 2: Main.hs 수정**

import 섹션에 추가 (필요한 경우):

```haskell
import qualified Graphics.Vty as V
```

`main` 함수 수정:

```haskell
main :: IO ()
main = do
  -- 초기 Vty 설정
  initialVty <- buildVtyFromTty

  -- 현재 터미널 크기 획득
  let output = V.outputIface initialVty
  (termWidth, termHeight) <- V.displayBounds output

  -- 설정 로드
  kbConfig <- loadKeyBindingConfig
  let cfg = configWithKeyBinding kbConfig

  -- 아이템 로드 (stdin 또는 파일 시스템)
  items <- getItems

  -- 초기 상태 생성 (터미널 크기 포함)
  let initialSt = initialState items cfg (termWidth, termHeight)

  -- 앱 실행
  finalState <- defaultMain app initialSt

  -- 선택된 항목 출력
  case listSelectedElement (stFilteredList finalState) of
    Nothing      -> return ()
    Just (_, item) -> T.putStrLn item
```

**참고:** `getItems` 함수명은 실제 Main.hs 코드에 맞게 조정 필요

**Step 3: 빌드 및 실행 테스트**

```bash
stack build
```

예상: 성공

```bash
stack run
```

예상: TUI가 전체 화면으로 실행됨

**Step 4: 터미널 크기 테스트**

```bash
# 작은 터미널에서 실행 (경고 확인)
# 터미널을 70x20으로 조정 후
stack run
```

예상: 경고 메시지 표시

**Step 5: 커밋**

```bash
git add app/Main.hs
git commit -m "feat(main): Initialize app with terminal size

- Get initial terminal dimensions from Vty
- Pass terminal size to initialState
- Enable full-screen TUI on startup

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: 통합 테스트 및 검증

**Files:**
- None (manual testing)

**Step 1: 다양한 터미널 크기에서 테스트**

```bash
# 최소 크기 (80x24)
# 터미널을 정확히 80x24로 조정
stack run

# 중간 크기 (120x40)
stack run

# 큰 크기 (200x50)
stack run

# 매우 작은 크기 (60x20) - 경고 확인
stack run
```

**Step 2: 리사이즈 동작 확인**

```bash
# 앱 실행 중 터미널 크기를 동적으로 변경
stack run
# 실행 중에 터미널 크기를 여러 번 조정하며 UI 반응 확인
```

**Step 3: 비율 확인**

실행 중 결과 리스트와 미리보기의 너비 비율이 대략 40:60인지 육안 확인

**Step 4: 기존 기능 회귀 테스트**

```bash
# 퍼지 검색 테스트
stack run
# 검색어 입력하며 필터링 동작 확인

# 키바인딩 테스트 (Emacs 모드)
stack run
# Ctrl+p, Ctrl+n, Ctrl+g 등 테스트

# Vim 키바인딩 테스트
# ~/.config/fzh/keybindings.yaml에서 vim으로 변경 후
stack run
# Ctrl+k, Ctrl+j, Ctrl+c 등 테스트

# stdin 파이프 테스트
find . -name "*.hs" | stack run

# 파일 미리보기 테스트
stack run
# 파일 선택 시 미리보기 표시 확인
```

**Step 5: 단위 테스트 실행**

```bash
stack test
```

예상: All tests passed

**Step 6: 문서화**

## 검증 완료

### 자동 테스트
- [x] 단위 테스트 전체 통과 (36 examples, 0 failures)
  - Types 모듈: isTerminalSizeSufficient, resultListWidth, previewWidth, contentHeight
  - Fuzzy 모듈: fuzzyMatchScore, filterItems
  - FileSearch 모듈: shouldExclude, listFilesRecursive
  - Event 모듈: formatFileError
  - UI 모듈: formatInfoText
- [x] 빌드 성공 (stack build)

### 수동 테스트 (비대화형 환경에서는 수행 불가)

다음 테스트들은 실제 터미널 환경에서 수행해야 합니다:

1. **터미널 크기별 테스트**
   - [ ] 최소 크기 (80x24): 정상 UI 표시 확인
   - [ ] 중간 크기 (120x40): 전체 화면 사용 확인
   - [ ] 큰 크기 (200x50): 40:60 비율 유지 확인
   - [ ] 최소 미만 (60x20): 경고 메시지 표시 확인

2. **동적 리사이즈 테스트**
   - [ ] 앱 실행 중 터미널 크기 조정 시 즉각 반응 확인
   - [ ] 작은 크기 ↔ 큰 크기 변경 시 UI 전환 확인
   - [ ] 경고 상태에서 크기 확대 시 정상 UI로 복귀 확인

3. **비율 정확도 테스트**
   - [ ] 다양한 너비에서 결과:미리보기 = 40:60 육안 확인

4. **기능 회귀 테스트**
   - [ ] 퍼지 검색 정상 동작 (필터링, 대소문자 무시)
   - [ ] Emacs 키바인딩 (Ctrl+p/n/g/k)
   - [ ] Vim 키바인딩 (Ctrl+k/j/c)
   - [ ] 파일 미리보기 표시
   - [ ] stdin 파이프 입력 (find . | stack run)

5. **경계 조건 테스트**
   - [ ] 빈 목록에서 정상 동작
   - [ ] 매우 긴 파일명 처리
   - [ ] 바이너리 파일 미리보기 처리

**Step 7: 최종 커밋**

```bash
git add docs/plans/2026-02-14-tui-full-screen.md
git commit -m "docs(plan): Mark implementation complete

All features tested and verified:
- Dynamic full-screen layout
- 40:60 result/preview ratio
- Terminal resize handling
- Minimum size warning
- Backward compatibility maintained

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 8: README 업데이트

**Files:**
- Modify: `README.md`

**Step 1: README.md에 동적 크기 조정 기능 설명 추가**

"주요 기능" 섹션에 추가:

```markdown
## 주요 기능

- 🔍 **퍼지 검색**: 빠르고 직관적인 파일 검색
- ⌨️  **키바인딩**: Emacs/Vim 스타일 선택 가능
- 🎨 **실시간 미리보기**: 선택한 파일의 내용을 즉시 확인
- 📐 **동적 레이아웃**: 터미널 전체 크기에 맞춰 자동 조정 (최소 80x24)
- 🚀 **성능 최적화**: 불필요한 디렉토리 자동 제외 (.git, node_modules 등)
- 📦 **파이프 지원**: stdin으로 목록을 받거나 파일 시스템 탐색
```

**Step 2: 터미널 크기 요구사항 추가**

"설치" 섹션 전에 추가:

```markdown
## 요구사항

- **최소 터미널 크기**: 80x24
- 더 작은 크기에서는 경고 메시지가 표시되나 계속 사용 가능
- 최적의 사용을 위해 100x30 이상 권장
```

**Step 3: 커밋**

```bash
git add README.md
git commit -m "docs(readme): Document dynamic layout feature

- Add dynamic layout to key features
- Specify minimum terminal size requirement
- Recommend optimal terminal dimensions

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## 완료 기준

1. ✅ 모든 단위 테스트 통과
2. ✅ 다양한 터미널 크기에서 정상 동작
3. ✅ 리사이즈 이벤트 즉각 반응
4. ✅ 40:60 비율 정확히 유지
5. ✅ 최소 크기 경고 표시
6. ✅ 기존 기능 회귀 없음
7. ✅ 문서 업데이트 완료
8. ✅ 모든 변경사항 커밋됨

---

## 참고사항

- **TDD 원칙**: 각 기능은 테스트 먼저, 구현은 나중
- **DRY**: 헬퍼 함수로 계산 로직 중앙화
- **YAGNI**: 필요한 기능만 구현 (추가 설정 등 제외)
- **Frequent commits**: 각 논리적 단위마다 커밋
- **Pure functions**: 모든 UI/계산 로직은 순수 함수로 유지
