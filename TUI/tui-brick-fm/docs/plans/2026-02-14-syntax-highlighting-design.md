# 구문 강조 기능 설계

## 개요

fzh 퍼지 파인더의 파일 미리보기에 구문 강조(syntax highlighting) 기능을 추가하여 코드 가독성을 향상시킵니다.

## 요구사항

### 기능 요구사항

1. **광범위한 언어 지원**: Skylighting 라이브러리를 사용하여 200개 이상의 프로그래밍 언어 지원
2. **기본 터미널 색상**: 모든 터미널에서 호환되는 기본 색상 사용
3. **대용량 파일 처리**: 처음 100줄만 표시하여 성능 보장
4. **라인 번호 표시**: 코드 위치 파악을 위한 라인 번호 추가
5. **폴백 메커니즘**: 구문 강조 실패 시 일반 텍스트로 표시

### 비기능 요구사항

- 기존 아키텍처 및 모듈화 원칙 유지
- 성능: 대용량 파일에서도 빠른 렌더링
- 호환성: 모든 터미널 환경에서 동작

## 아키텍처

### 모듈 구조

새로운 `SyntaxHighlight` 모듈을 추가하여 기존 아키텍처를 확장합니다:

```
기존:
UI.hs → Types.hs → Config.hs
  ↓
renderFilePreview (단순 텍스트)

변경 후:
UI.hs → SyntaxHighlight.hs → Types.hs
  ↓           ↓
  └─────> Skylighting 라이브러리
```

### 의존성 추가

`package.yaml`에 추가할 의존성:

```yaml
dependencies:
- skylighting >= 0.14
- skylighting-core >= 0.14
```

### 모듈 책임

- **SyntaxHighlight.hs**: 파일 확장자로 언어 감지, 토큰화, 색상 적용, 라인 번호 추가
- **UI.hs**: `renderFilePreview`에서 `SyntaxHighlight` 호출
- **Lib.hs**: 구문 강조용 색상 속성을 `attrMap`에 추가
- **Types.hs**: 변경 불필요 (기존 타입 재사용)

## 컴포넌트 설계

### SyntaxHighlight 모듈

새로운 `src/SyntaxHighlight.hs` 모듈의 주요 함수:

```haskell
module SyntaxHighlight
  ( renderHighlightedContent
  , detectLanguage
  ) where

import Skylighting

-- | 파일 경로와 내용을 받아 구문 강조된 위젯 반환
renderHighlightedContent :: FilePath -> Text -> Widget n

-- | 파일 확장자로 Syntax 감지 (내부 헬퍼)
detectLanguage :: FilePath -> Maybe Syntax
```

#### renderHighlightedContent 함수 동작

1. 처음 100줄만 추출
2. 파일 확장자로 언어 감지
3. Skylighting으로 토큰화
4. 각 토큰에 색상 속성 적용
5. 라인 번호 추가
6. 언어 감지 실패 시 일반 텍스트로 폴백

### UI.hs 변경

`renderFilePreview` 함수 수정:

```haskell
-- 변경 전:
renderFilePreview _cfg st =
  borderWithLabel (txt "Preview") $
  padLeftRight 1 $
  case stFileContent st of
    Nothing      -> txt "No file selected"
    Just content -> txtWrap content

-- 변경 후:
renderFilePreview _cfg st =
  borderWithLabel (txt "Preview") $
  padLeftRight 1 $
  case stFileContent st of
    Nothing      -> txt "No file selected"
    Just content -> renderHighlightedContent selectedPath content
      where
        selectedPath = case listSelectedElement (stFilteredList st) of
          Just (_, path) -> T.unpack path
          Nothing        -> ""
```

### Lib.hs 변경

`attrMap`에 구문 강조용 색상 속성 추가:

```haskell
mkAttrMap :: AppState -> AttrMap
mkAttrMap st = attrMap (configDefaultAttr cfg)
  [ (listSelectedAttr, configSelectedAttr cfg)
  -- 구문 강조 색상
  , (attrName "syntax.keyword", fg brightBlue)
  , (attrName "syntax.string", fg yellow)
  , (attrName "syntax.comment", fg brightBlack)
  , (attrName "syntax.function", fg brightGreen)
  , (attrName "syntax.type", fg brightCyan)
  , (attrName "syntax.number", fg cyan)
  , (attrName "syntax.lineNumber", fg brightBlack)
  ]
  where
    cfg = stConfig st
```

## 데이터 흐름

### 파일 미리보기 렌더링 흐름

```
1. 사용자가 파일 선택
   ↓
2. Event.hs:loadSelectedFile
   - 파일 내용을 Text로 로드
   - stFileContent에 저장
   ↓
3. UI.hs:renderFilePreview
   - 선택된 파일 경로 추출
   - stFileContent와 경로를 함께 전달
   ↓
4. SyntaxHighlight.hs:renderHighlightedContent
   - 처음 100줄 추출 (Text.lines + take 100)
   - detectLanguage로 언어 감지
   - 성공: Skylighting tokenize 호출
   - 실패: 일반 텍스트로 처리
   ↓
5. 토큰별 색상 적용
   - KeywordTok → "syntax.keyword" 속성
   - StringTok → "syntax.string" 속성
   - CommentTok → "syntax.comment" 속성
   - 등...
   ↓
6. 라인 번호 추가
   - 각 줄 앞에 "  1 | ", "  2 | " 등 추가
   - 라인 번호는 "syntax.lineNumber" 속성 사용
   ↓
7. Widget n 반환
   - vBox로 모든 줄 결합
   - UI.hs가 borderWithLabel로 감싸서 표시
```

### 상태 변경 없음

중요: `AppState`에는 변경이 없습니다. 기존 `stFileContent :: Maybe Text` 그대로 사용하고, 구문 강조는 렌더링 시점에만 수행됩니다.

## 에러 처리 및 폴백

### 폴백 시나리오

구문 강조가 실패할 수 있는 경우와 대응 방법:

#### 1. 언어 감지 실패

- **상황**: 파일 확장자가 없거나 알 수 없는 확장자 (예: `.txt`, `.conf`, `.lock`)
- **대응**: 라인 번호만 추가하고 일반 텍스트로 표시

#### 2. Skylighting 토큰화 실패

- **상황**: 구문 오류가 있는 소스 코드
- **대응**: 일반 텍스트로 폴백 (예외 catch)

#### 3. 바이너리 파일

- **상황**: UTF-8 디코딩 실패
- **대응**: 이미 `Event.hs:loadFileContent`에서 처리됨 (에러 메시지 표시)

### 구현 방식

```haskell
renderHighlightedContent :: FilePath -> Text -> Widget n
renderHighlightedContent path content =
  let contentLines = take 100 $ T.lines content
  in case detectLanguage path of
       Nothing -> renderPlainText contentLines  -- 폴백 1
       Just syntax ->
         case tokenize config syntax content of
           Left _err -> renderPlainText contentLines  -- 폴백 2
           Right tokens -> renderHighlighted tokens

renderPlainText :: [Text] -> Widget n
renderPlainText lines =
  vBox $ zipWith addLineNumber [1..] lines
  where
    addLineNumber n line =
      hBox [ withAttr (attrName "syntax.lineNumber")
               (str $ printf "%3d | " n)
           , txt line
           ]
```

### 사용자 피드백

- 구문 강조 실패 시에도 내용은 항상 표시됨
- 라인 번호는 항상 표시됨
- 에러 메시지 없음 (조용한 폴백)

## 성능 최적화

### 1. 100줄 제한

- 파일 로드는 전체를 읽지만, 렌더링은 처음 100줄만
- 큰 파일에서도 일정한 렌더링 성능 보장
- 잘린 경우 미리보기 하단에 표시: `"... (총 1000줄 중 100줄 표시)"`

### 2. 렌더링 시점 처리

- 구문 강조는 렌더링 시점에만 수행 (상태에 저장 안 함)
- 메모리 사용 최소화
- Brick의 효율적인 렌더링 엔진 활용

### 3. 언어 감지 캐싱 불필요

- 파일 확장자 기반 감지는 매우 빠름 (O(1) Map lookup)
- 추가 캐싱 오버헤드 불필요

## 테스팅 전략

### 단위 테스트

`test/Spec.hs`에 추가할 테스트:

```haskell
-- 1. 언어 감지 테스트
spec_detectLanguage :: Spec
spec_detectLanguage = do
  it "detects Haskell files" $
    detectLanguage "test.hs" `shouldSatisfy` isJust
  it "detects Python files" $
    detectLanguage "test.py" `shouldSatisfy` isJust
  it "returns Nothing for unknown extensions" $
    detectLanguage "test.unknown" `shouldBe` Nothing

-- 2. 라인 제한 테스트
spec_lineLimit :: Spec
spec_lineLimit = do
  it "limits to 100 lines" $
    let content = T.unlines (replicate 200 "line")
    in length (extractLines content) `shouldBe` 100
```

### 수동 테스트

- 다양한 언어 파일로 테스트 (Haskell, Python, JavaScript, etc.)
- 대용량 파일 테스트 (1000줄 이상)
- 잘못된 구문이 있는 파일 테스트
- 바이너리 파일 테스트

## 색상 스키마

### 기본 터미널 색상 매핑

| 토큰 타입 | 색상 | Vty Attr |
|----------|------|----------|
| 키워드 (keyword) | 파란색 | `fg brightBlue` |
| 함수/타입 (function, type) | 초록색 | `fg brightGreen` / `fg brightCyan` |
| 문자열 (string) | 노란색 | `fg yellow` |
| 주석 (comment) | 회색 | `fg brightBlack` |
| 숫자 (number) | 청록색 | `fg cyan` |
| 라인 번호 | 회색 | `fg brightBlack` |

## 구현 계획

다음 단계는 `writing-plans` 스킬을 사용하여 상세한 구현 계획을 작성합니다.

### 주요 구현 작업

1. `package.yaml`에 skylighting 의존성 추가
2. `src/SyntaxHighlight.hs` 모듈 생성
3. `src/Lib.hs`에 색상 속성 추가
4. `src/UI.hs`의 `renderFilePreview` 수정
5. 단위 테스트 추가
6. 수동 테스트 및 검증

## 설계 승인

- 아키텍처 개요: ✅
- 컴포넌트 설계: ✅
- 데이터 흐름: ✅
- 에러 처리 및 폴백: ✅
- 성능 최적화 및 테스팅: ✅

설계 승인 날짜: 2026-02-14
