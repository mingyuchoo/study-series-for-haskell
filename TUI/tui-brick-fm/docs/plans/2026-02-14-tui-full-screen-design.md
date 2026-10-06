# TUI 전체 화면 사용 디자인

**날짜:** 2026-02-14
**상태:** 승인됨
**작성자:** Claude Code

## 개요

현재 fzh TUI 애플리케이션은 고정 크기(`vLimit 20`, `configMaxWidth = 80`)를 사용하여 터미널의 작은 영역만 차지합니다. 이를 터미널 전체 크기를 동적으로 활용하도록 개선합니다.

## 요구사항

### 기능 요구사항

1. **동적 크기 조정**
   - 터미널 크기에 맞춰 모든 UI 요소가 동적으로 확장/축소
   - 결과 리스트와 미리보기가 사용 가능한 전체 높이 활용
   - 너비도 터미널 전체 너비 사용

2. **수평 분할 비율**
   - 결과 리스트: 40%
   - 파일 미리보기: 60%

3. **고정 요소 크기**
   - 검색 박스: 3줄 고정 (테두리 포함)
   - 정보 표시줄: 3줄 고정 (테두리 포함)
   - 키바인딩 도움말: 1-2줄 고정
   - 나머지 공간: 결과 리스트/미리보기가 사용

4. **최소 크기 경고**
   - 터미널이 80x24 미만일 때 경고 메시지 표시
   - 경고 표시 중에도 앱은 계속 동작
   - 크기를 키우면 즉시 정상 UI로 전환

### 비기능 요구사항

- 기존 기능 유지 (퍼지 검색, 키바인딩, 미리보기)
- 리사이즈 이벤트에 즉각 반응
- 성능 저하 없음

## 아키텍처

### 레이아웃 구조

```
┌─────────────────────────────────────┐
│ Search Box (3줄 고정)               │
├─────────────┬───────────────────────┤
│ Results     │ Preview              │
│ (40% 너비)  │ (60% 너비)            │
│ (동적 높이) │ (동적 높이)           │
├─────────────┴───────────────────────┤
│ Info (3줄 고정)                     │
├─────────────────────────────────────┤
│ Help (1-2줄 고정)                   │
└─────────────────────────────────────┘
```

### 변경 계층

1. **데이터 모델 (Types.hs)**
   - `AppState`에 터미널 크기 정보 추가
   - 헬퍼 함수 추가 (크기 계산, 유효성 검사)

2. **UI 렌더링 (UI.hs)**
   - 고정 크기 제한 제거
   - 터미널 크기 기반 동적 계산
   - 경고 UI 추가

3. **이벤트 핸들링 (Event.hs)**
   - 리사이즈 이벤트 처리

4. **초기화 (Main.hs)**
   - 초기 터미널 크기 획득

## 데이터 모델 변경

### AppState 수정

```haskell
data AppState = AppState
  { stItems        :: !(Vec.Vector T.Text)
  , stFilteredList :: !(List Name T.Text)
  , stSearchQuery  :: !T.Text
  , stConfig       :: !AppConfig
  , stFileContent  :: !(Maybe T.Text)
  , stTerminalSize :: !(Int, Int)  -- 새로 추가: (width, height)
  }
```

### 헬퍼 함수

```haskell
-- | 터미널이 최소 크기 이상인지 확인
isTerminalSizeSufficient :: (Int, Int) -> Bool
isTerminalSizeSufficient (w, h) = w >= 80 && h >= 24

-- | 결과 리스트 너비 계산 (40%)
resultListWidth :: Int -> Int
resultListWidth termWidth = (termWidth * 2) `div` 5

-- | 미리보기 너비 계산 (60%)
previewWidth :: Int -> Int
previewWidth termWidth = termWidth - resultListWidth termWidth

-- | 컨텐츠 영역 높이 계산 (전체 - 고정 요소들)
contentHeight :: Int -> Int
contentHeight termHeight = termHeight - 3 - 3 - 2  -- search(3) + info(3) + help(2)
```

### initialState 수정

```haskell
initialState :: [T.Text] -> AppConfig -> (Int, Int) -> AppState
initialState items cfg termSize =
  let itemVec = Vec.fromList items
  in AppState
       { stItems        = itemVec
       , stFilteredList = list ItemList itemVec 1
       , stSearchQuery  = ""
       , stConfig       = cfg
       , stFileContent  = Nothing
       , stTerminalSize = termSize  -- 초기 터미널 크기
       }
```

## UI 렌더링 로직

### drawUI 함수 재구성

```haskell
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

### 정상 UI 렌더링

```haskell
renderNormalUI :: AppState -> Int -> Int -> AppConfig -> Widget Name
renderNormalUI st termWidth termHeight cfg = vBox
  [ renderSearchBox st termWidth
  , hBox
      [ vLimit (contentHeight termHeight) $
        hLimit (resultListWidth termWidth) $
        renderResultList cfg st
      , vLimit (contentHeight termHeight) $
        hLimit (previewWidth termWidth) $
        renderFilePreview cfg st
      ]
  , renderInfo cfg st termWidth
  , padTop (Pad 1) $ hCenter $ renderKeyBindingHelp cfg
  ]
```

### 경고 UI 렌더링

```haskell
renderWarningUI :: AppState -> Widget Name
renderWarningUI st =
  let (w, h) = stTerminalSize st
      warning = vCenter $ hCenter $ vBox
        [ txt "⚠️  터미널 크기가 너무 작습니다"
        , txt ""
        , txt $ "현재: " <> T.pack (show w) <> "x" <> T.pack (show h)
        , txt $ "최소: 80x24"
        , txt ""
        , txt "터미널 크기를 조정해주세요"
        ]
  in border warning
```

### 개별 렌더링 함수 수정

```haskell
-- 너비를 파라미터로 받도록 변경
renderSearchBox :: AppState -> Int -> Widget Name
renderSearchBox st termWidth =
  hLimit termWidth $
  borderWithLabel (txt "Search") $
  padLeftRight 1 $
  txt (stSearchQuery st <> "_")

-- configMaxWidth 제거
renderInfo :: AppConfig -> AppState -> Int -> Widget Name
renderInfo cfg st termWidth =
  hLimit termWidth $
  border $
  padLeftRight 1 $
  txt $ formatInfoText totalItems selectedIdx
  where
    totalItems = Vec.length $ listElements $ stFilteredList st
    selectedIdx = fst <$> listSelectedElement (stFilteredList st)
```

## 이벤트 핸들링

### 리사이즈 이벤트 처리

**Event.hs:**

```haskell
handleEvent :: BrickEvent Name e -> EventM Name AppState ()
handleEvent e = case e of
  -- 기존 이벤트 핸들러들...

  -- 새로 추가: 터미널 리사이즈 처리
  VtyEvent (V.EvResize w h) -> do
    modify $ \st -> st { stTerminalSize = (w, h) }

  -- 기타 이벤트들...
  _ -> return ()
```

### 초기 터미널 크기 획득

**Main.hs:**

```haskell
main :: IO ()
main = do
  -- 초기 Vty 설정
  initialVty <- buildVtyFromTty

  -- 현재 터미널 크기 획득
  output <- V.outputIface initialVty
  (termWidth, termHeight) <- V.displayBounds output

  -- 설정 로드
  kbConfig <- loadKeyBindingConfig
  let cfg = configWithKeyBinding kbConfig

  -- 아이템 로드 (stdin 또는 파일 시스템)
  items <- loadItems

  -- 초기 상태 생성 (터미널 크기 포함)
  let initialSt = initialState items cfg (termWidth, termHeight)

  -- 앱 실행
  finalState <- defaultMain app initialSt

  -- 선택된 항목 출력
  printSelectedItem finalState
```

## 테스팅 전략

### 수동 테스트 시나리오

**터미널 크기 테스트:**
```bash
# 작은 크기 (경고 확인)
stack run  # 터미널을 60x20으로 조정

# 최소 크기 (경계 케이스)
stack run  # 터미널을 정확히 80x24로 조정

# 큰 크기
stack run  # 터미널을 200x50으로 조정

# 리사이즈 동작 확인
stack run  # 실행 중 터미널 크기 동적 변경
```

### 단위 테스트

**test/Spec.hs에 추가:**

```haskell
testTerminalSizeCheck :: Test
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

testLayoutCalculations :: Test
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

### 검증 체크리스트

- [ ] 터미널 전체 영역 사용 확인
- [ ] 40:60 비율 정확도 확인
- [ ] 리사이즈 시 즉각 반응 확인
- [ ] 80x24 미만에서 경고 표시 확인
- [ ] 경고 후에도 80x24 이상으로 키우면 정상 동작
- [ ] 기존 키바인딩 모두 정상 동작
- [ ] 퍼지 검색 정상 동작
- [ ] 파일 미리보기 정상 동작

### 엣지 케이스

- 터미널 크기가 0x0인 경우
- 매우 긴 파일명/경로 처리
- 빈 검색 결과
- 미리보기 불가능한 파일 (바이너리 등)

## 구현 순서

1. Types.hs 수정 (데이터 모델, 헬퍼 함수)
2. UI.hs 수정 (렌더링 로직)
3. Event.hs 수정 (리사이즈 이벤트)
4. Main.hs 수정 (초기 크기 획득)
5. 단위 테스트 추가
6. 수동 테스트 수행
7. 문서 업데이트

## 하위 호환성

- `configMaxWidth` 필드는 유지하되 사용하지 않음
- 기존 설정 파일 그대로 동작
- 기존 키바인딩 모두 유지

## 성능 고려사항

- 리사이즈 이벤트는 빈번하지 않으므로 성능 영향 미미
- 크기 계산은 간단한 산술 연산으로 O(1)
- Brick의 레이아웃 엔진이 효율적으로 처리

## 결론

이 디자인은 하이브리드 접근 방식을 채택하여 Brick의 레이아웃 엔진을 최대한 활용하면서도 필요한 부분만 명시적으로 제어합니다. 40:60 비율을 정확히 구현하고, 최소 크기 경고를 자연스럽게 통합하며, 코드 변경을 최소화하여 유지보수성을 높입니다.
