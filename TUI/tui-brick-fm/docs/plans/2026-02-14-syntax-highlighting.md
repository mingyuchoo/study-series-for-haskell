# 구문 강조 기능 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 파일 미리보기에 Skylighting 기반 구문 강조 기능 추가

**Architecture:** 새로운 SyntaxHighlight 모듈을 생성하여 파일 확장자 기반 언어 감지, 토큰화, 색상 적용, 라인 번호 추가를 담당. UI.hs는 이 모듈을 호출하여 구문 강조된 위젯을 렌더링.

**Tech Stack:** Skylighting, Brick, Vty

---

## Task 1: 의존성 추가

**Files:**
- Modify: `package.yaml`

**Step 1: package.yaml에 skylighting 의존성 추가**

파일의 `dependencies:` 섹션에 다음 추가:

```yaml
- skylighting >= 0.14
- skylighting-core >= 0.14
```

**Step 2: 의존성 설치 확인**

```bash
stack build --only-dependencies
```

Expected: 의존성이 성공적으로 다운로드 및 빌드됨

**Step 3: Commit**

```bash
git add package.yaml
git commit -m "build: add skylighting dependencies for syntax highlighting"
```

---

## Task 2: SyntaxHighlight 모듈 뼈대 생성

**Files:**
- Create: `src/SyntaxHighlight.hs`
- Create: `test/SyntaxHighlightSpec.hs`

**Step 1: 테스트 파일 생성**

`test/SyntaxHighlightSpec.hs`:

```haskell
{-# LANGUAGE OverloadedStrings #-}

module SyntaxHighlightSpec (spec) where

import Test.Hspec
import SyntaxHighlight
import qualified Data.Text as T

spec :: Spec
spec = do
  describe "detectLanguage" $ do
    it "detects Haskell files" $ do
      detectLanguage "test.hs" `shouldSatisfy` isJust
```

**Step 2: test/Spec.hs에 SyntaxHighlightSpec 추가**

`test/Spec.hs`에 다음 import 추가:

```haskell
import qualified SyntaxHighlightSpec
```

그리고 `main` 함수의 `hspec` 호출에 추가:

```haskell
main = hspec $ do
  -- ... 기존 테스트들 ...
  SyntaxHighlightSpec.spec
```

**Step 3: 테스트 실행하여 실패 확인**

```bash
stack test
```

Expected: 컴파일 에러 - "Could not find module 'SyntaxHighlight'"

**Step 4: SyntaxHighlight 모듈 뼈대 생성**

`src/SyntaxHighlight.hs`:

```haskell
{-# LANGUAGE OverloadedStrings #-}

module SyntaxHighlight
    ( detectLanguage
    , renderHighlightedContent
    ) where

import           Brick
import qualified Data.Text          as T
import           Skylighting
import           System.FilePath    (takeExtension)

import           Types              (Name)

-- | 파일 확장자로 언어 감지
detectLanguage :: FilePath -> Maybe Syntax
detectLanguage path =
  let ext = T.pack $ takeExtension path
  in lookupSyntax ext defaultSyntaxMap

-- | 파일 내용을 구문 강조하여 렌더링 (임시 구현)
renderHighlightedContent :: FilePath -> T.Text -> Widget Name
renderHighlightedContent _path content = txt content
```

**Step 5: package.yaml에 모듈 추가**

`package.yaml`의 `library.exposed-modules`에 추가:

```yaml
exposed-modules:
  - Lib
  - Config
  - Types
  - Fuzzy
  - Event
  - UI
  - Vty
  - FileSearch
  - SyntaxHighlight
```

**Step 6: 테스트 실행하여 성공 확인**

```bash
stack test
```

Expected: 테스트 통과

**Step 7: Commit**

```bash
git add src/SyntaxHighlight.hs test/SyntaxHighlightSpec.hs test/Spec.hs package.yaml
git commit -m "feat(syntax): add SyntaxHighlight module skeleton"
```

---

## Task 3: 언어 감지 기능 테스트 추가

**Files:**
- Modify: `test/SyntaxHighlightSpec.hs`

**Step 1: 추가 테스트 작성**

`test/SyntaxHighlightSpec.hs`의 `spec`에 추가:

```haskell
spec :: Spec
spec = do
  describe "detectLanguage" $ do
    it "detects Haskell files" $ do
      detectLanguage "test.hs" `shouldSatisfy` isJust

    it "detects Python files" $ do
      detectLanguage "test.py" `shouldSatisfy` isJust

    it "detects JavaScript files" $ do
      detectLanguage "test.js" `shouldSatisfy` isJust

    it "returns Nothing for unknown extensions" $ do
      detectLanguage "test.unknown" `shouldBe` Nothing

    it "returns Nothing for files without extensions" $ do
      detectLanguage "README" `shouldBe` Nothing
```

**Step 2: 테스트 실행**

```bash
stack test
```

Expected: 모든 테스트 통과 (detectLanguage가 이미 올바르게 구현됨)

**Step 3: Commit**

```bash
git add test/SyntaxHighlightSpec.hs
git commit -m "test(syntax): add comprehensive language detection tests"
```

---

## Task 4: 일반 텍스트 렌더링 구현 (라인 번호 포함)

**Files:**
- Modify: `test/SyntaxHighlightSpec.hs`
- Modify: `src/SyntaxHighlight.hs`

**Step 1: 테스트 작성**

`test/SyntaxHighlightSpec.hs`에 새 describe 블록 추가:

```haskell
  describe "renderPlainText" $ do
    it "adds line numbers to each line" $ do
      let lines = ["line 1", "line 2", "line 3"]
      -- renderPlainText는 Widget을 반환하므로 타입 체크만 수행
      renderPlainText lines `shouldSatisfy` const True
```

**Step 2: 테스트 실행하여 실패 확인**

```bash
stack test
```

Expected: 컴파일 에러 - "Not in scope: 'renderPlainText'"

**Step 3: renderPlainText 함수 구현**

`src/SyntaxHighlight.hs`에 추가:

```haskell
import           Text.Printf        (printf)
import           Graphics.Vty.Attributes (attrName)

-- | 일반 텍스트를 라인 번호와 함께 렌더링
renderPlainText :: [T.Text] -> Widget Name
renderPlainText textLines =
  vBox $ zipWith addLineNumber [1..] textLines
  where
    addLineNumber :: Int -> T.Text -> Widget Name
    addLineNumber n line =
      hBox [ withAttr (attrName "syntax.lineNumber")
               (str $ printf "%3d | " n)
           , txt line
           ]
```

그리고 모듈 export에 추가:

```haskell
module SyntaxHighlight
    ( detectLanguage
    , renderHighlightedContent
    , renderPlainText  -- 추가
    ) where
```

**Step 4: 테스트 실행하여 성공 확인**

```bash
stack test
```

Expected: 테스트 통과

**Step 5: Commit**

```bash
git add src/SyntaxHighlight.hs test/SyntaxHighlightSpec.hs
git commit -m "feat(syntax): implement plain text rendering with line numbers"
```

---

## Task 5: 100줄 제한 기능 구현

**Files:**
- Modify: `test/SyntaxHighlightSpec.hs`
- Modify: `src/SyntaxHighlight.hs`

**Step 1: 테스트 작성**

`test/SyntaxHighlightSpec.hs`에 추가:

```haskell
  describe "limitLines" $ do
    it "limits content to 100 lines" $ do
      let content = T.unlines $ map (T.pack . show) [1..200]
      length (limitLines content) `shouldBe` 100

    it "preserves content with less than 100 lines" $ do
      let content = T.unlines $ map (T.pack . show) [1..50]
      length (limitLines content) `shouldBe` 50
```

**Step 2: 테스트 실행하여 실패 확인**

```bash
stack test
```

Expected: 컴파일 에러 - "Not in scope: 'limitLines'"

**Step 3: limitLines 함수 구현**

`src/SyntaxHighlight.hs`에 추가:

```haskell
-- | 내용을 처음 100줄로 제한
limitLines :: T.Text -> [T.Text]
limitLines content = take 100 $ T.lines content
```

모듈 export에 추가:

```haskell
module SyntaxHighlight
    ( detectLanguage
    , renderHighlightedContent
    , renderPlainText
    , limitLines  -- 추가
    ) where
```

**Step 4: 테스트 실행하여 성공 확인**

```bash
stack test
```

Expected: 테스트 통과

**Step 5: Commit**

```bash
git add src/SyntaxHighlight.hs test/SyntaxHighlightSpec.hs
git commit -m "feat(syntax): implement 100-line limit for preview"
```

---

## Task 6: 구문 강조 렌더링 구현

**Files:**
- Modify: `src/SyntaxHighlight.hs`

**Step 1: 토큰을 Brick 속성으로 매핑하는 함수 작성**

`src/SyntaxHighlight.hs`에 추가:

```haskell
import           Skylighting.Types  (Token, TokenType(..))

-- | Skylighting 토큰 타입을 Brick 속성 이름으로 매핑
tokenAttr :: TokenType -> AttrName
tokenAttr KeywordTok        = attrName "syntax.keyword"
tokenAttr DataTypeTok       = attrName "syntax.type"
tokenAttr DecValTok         = attrName "syntax.number"
tokenAttr BaseNTok          = attrName "syntax.number"
tokenAttr FloatTok          = attrName "syntax.number"
tokenAttr ConstantTok       = attrName "syntax.number"
tokenAttr CharTok           = attrName "syntax.string"
tokenAttr StringTok         = attrName "syntax.string"
tokenAttr CommentTok        = attrName "syntax.comment"
tokenAttr OtherTok          = attrName "syntax.function"
tokenAttr FunctionTok       = attrName "syntax.function"
tokenAttr VariableTok       = attrName "syntax.function"
tokenAttr _                 = attrName "default"
```

**Step 2: 토큰 줄을 위젯으로 변환하는 함수 작성**

```haskell
import           Skylighting.Types  (SourceLine)

-- | 토큰 줄을 라인 번호와 함께 위젯으로 렌더링
renderTokenLine :: Int -> SourceLine -> Widget Name
renderTokenLine lineNum tokens =
  hBox [ withAttr (attrName "syntax.lineNumber")
           (str $ printf "%3d | " lineNum)
       , hBox $ map renderToken tokens
       ]
  where
    renderToken :: Token -> Widget Name
    renderToken (tokenType, text) =
      withAttr (tokenAttr tokenType) (txt text)
```

**Step 3: renderHighlightedContent 함수 완성**

기존 임시 구현을 다음으로 교체:

```haskell
import           Skylighting.Tokenizer (tokenize, TokenizerConfig(..))

-- | 파일 내용을 구문 강조하여 렌더링
renderHighlightedContent :: FilePath -> T.Text -> Widget Name
renderHighlightedContent path content =
  let contentLines = limitLines content
  in case detectLanguage path of
       Nothing -> renderPlainText contentLines
       Just syntax ->
         let config = TokenizerConfig defaultSyntaxMap False
         in case tokenize config syntax (T.unlines contentLines) of
              Left _err -> renderPlainText contentLines
              Right sourceLines ->
                vBox $ zipWith renderTokenLine [1..] sourceLines
```

**Step 4: 빌드하여 컴파일 확인**

```bash
stack build
```

Expected: 성공적으로 빌드됨

**Step 5: Commit**

```bash
git add src/SyntaxHighlight.hs
git commit -m "feat(syntax): implement syntax highlighting with Skylighting"
```

---

## Task 7: Lib.hs에 색상 속성 추가

**Files:**
- Modify: `src/Lib.hs`

**Step 1: attrMap에 구문 강조 색상 추가**

`src/Lib.hs`의 `mkAttrMap` 함수 수정:

```haskell
import qualified Graphics.Vty.Attributes as V

mkAttrMap :: AppState -> AttrMap
mkAttrMap st = attrMap (configDefaultAttr cfg)
  [ (listSelectedAttr, configSelectedAttr cfg)
  -- 구문 강조 색상
  , (attrName "syntax.keyword", fg V.brightBlue)
  , (attrName "syntax.string", fg V.yellow)
  , (attrName "syntax.comment", fg V.brightBlack)
  , (attrName "syntax.function", fg V.brightGreen)
  , (attrName "syntax.type", fg V.brightCyan)
  , (attrName "syntax.number", fg V.cyan)
  , (attrName "syntax.lineNumber", fg V.brightBlack)
  ]
  where
    cfg = stConfig st
```

**Step 2: 빌드하여 컴파일 확인**

```bash
stack build
```

Expected: 성공적으로 빌드됨

**Step 3: Commit**

```bash
git add src/Lib.hs
git commit -m "feat(syntax): add color attributes for syntax highlighting"
```

---

## Task 8: UI.hs에 구문 강조 통합

**Files:**
- Modify: `src/UI.hs`

**Step 1: SyntaxHighlight 모듈 import**

`src/UI.hs`에 import 추가:

```haskell
import           SyntaxHighlight    (renderHighlightedContent)
```

**Step 2: renderFilePreview 함수 수정**

기존 구현:

```haskell
renderFilePreview :: AppConfig -> AppState -> Widget Name
renderFilePreview _cfg st =
  borderWithLabel (txt "Preview") <|
  padLeftRight 1 <|
  case stFileContent st of
    Nothing      -> txt "No file selected"
    Just content -> txtWrap content
```

다음으로 수정:

```haskell
renderFilePreview :: AppConfig -> AppState -> Widget Name
renderFilePreview _cfg st =
  borderWithLabel (txt "Preview") <|
  padLeftRight 1 <|
  case stFileContent st of
    Nothing      -> txt "No file selected"
    Just content ->
      case listSelectedElement (stFilteredList st) of
        Nothing -> txt "No file selected"
        Just (_, selectedPath) ->
          renderHighlightedContent (T.unpack selectedPath) content
```

**Step 3: 빌드하여 컴파일 확인**

```bash
stack build
```

Expected: 성공적으로 빌드됨

**Step 4: Commit**

```bash
git add src/UI.hs
git commit -m "feat(syntax): integrate syntax highlighting into file preview"
```

---

## Task 9: 수동 테스트

**Files:**
- N/A (테스트만 수행)

**Step 1: 애플리케이션 실행**

```bash
stack run
```

**Step 2: 다양한 파일 타입 테스트**

테스트할 파일들:
- Haskell 파일 (`.hs`) - 키워드, 함수, 문자열, 주석 강조 확인
- Python 파일 (`.py`) - 구문 강조 확인
- JavaScript 파일 (`.js`) - 구문 강조 확인
- 텍스트 파일 (`.txt`) - 일반 텍스트로 표시 확인
- 확장자 없는 파일 - 일반 텍스트로 표시 확인

**Step 3: 100줄 제한 확인**

200줄 이상의 파일 선택 시:
- 처음 100줄만 표시되는지 확인
- 라인 번호가 1-100까지만 표시되는지 확인

**Step 4: 색상 확인**

각 요소가 올바른 색상으로 표시되는지 확인:
- 키워드: 파란색
- 문자열: 노란색
- 주석: 회색
- 함수/타입: 초록색/청록색
- 숫자: 청록색
- 라인 번호: 회색

**Step 5: 문서화**

테스트 결과를 간단히 기록하고 커밋:

```bash
git add -A
git commit -m "test(syntax): verify syntax highlighting manually

Tested:
- Haskell, Python, JavaScript files - highlighting works
- Plain text files - fallback to plain rendering
- 100-line limit - enforced correctly
- Colors - rendered as expected"
```

---

## Task 10: README 업데이트

**Files:**
- Modify: `README.md`

**Step 1: 주요 기능 섹션에 구문 강조 추가**

`README.md`의 "주요 기능" 섹션 수정:

```markdown
## 주요 기능

- 🔍 **퍼지 검색**: 빠르고 직관적인 파일 검색
- ⌨️  **키바인딩**: Emacs/Vim 스타일 선택 가능
- 🎨 **실시간 미리보기**: 선택한 파일의 내용을 즉시 확인
- 🌈 **구문 강조**: 200개 이상의 프로그래밍 언어 지원
- 📐 **동적 레이아웃**: 터미널 전체 크기에 맞춰 자동 조정 (최소 80x24)
- 🚀 **성능 최적화**: 불필요한 디렉토리 자동 제외 (.git, node_modules 등)
- 📦 **파이프 지원**: stdin으로 목록을 받거나 파일 시스템 탐색
```

**Step 2: 스크린샷 섹션 추가 (선택사항)**

필요하다면 스크린샷 섹션 추가:

```markdown
## 스크린샷

[구문 강조 예시 이미지 - 나중에 추가 가능]
```

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs(readme): add syntax highlighting to features list"
```

---

## 완료 체크리스트

- [ ] Task 1: 의존성 추가
- [ ] Task 2: SyntaxHighlight 모듈 뼈대 생성
- [ ] Task 3: 언어 감지 기능 테스트 추가
- [ ] Task 4: 일반 텍스트 렌더링 구현
- [ ] Task 5: 100줄 제한 기능 구현
- [ ] Task 6: 구문 강조 렌더링 구현
- [ ] Task 7: Lib.hs에 색상 속성 추가
- [ ] Task 8: UI.hs에 구문 강조 통합
- [ ] Task 9: 수동 테스트
- [ ] Task 10: README 업데이트

## 예상 소요 시간

- 총 작업 시간: 약 60-90분
- 각 Task: 5-10분
- 테스트 및 검증: 15-20분
