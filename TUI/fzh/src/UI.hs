{-# LANGUAGE OverloadedStrings #-}

module UI
    ( drawUI
    , formatInfoText
    , renderWarningUI
    ) where
import           Brick
import           Brick.Widgets.Border
import           Brick.Widgets.Center
import           Brick.Widgets.List

import           Config               (KeyBindingStyle (..))

import qualified Data.Text            as T
import qualified Data.Vector          as Vec

import           Flow                 ((<|))

import           Types                (AppConfig (..), AppState (..), Name,
                                       contentHeight, isTerminalSizeSufficient,
                                       previewWidth, resultListWidth)

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

-- | 검색 입력 박스 렌더링 (Pure)
-- 현재 검색어와 커서(_) 표시
-- 터미널 너비에 맞춰 동적 조정
renderSearchBox :: AppState -> Int -> Widget Name
renderSearchBox st termWidth =
  hLimit termWidth <|
  borderWithLabel (txt "Search") <|
  padLeftRight 1 <|
  txt (stSearchQuery st <> "_")

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

-- | 정보 텍스트 생성 (Pure)
-- 아이템 개수와 선택 위치를 포맷팅
formatInfoText :: Int -> Maybe Int -> T.Text
formatInfoText total Nothing = "Items: " <> T.pack (show total)
formatInfoText total (Just idx) =
  "Items: " <> T.pack (show total) <> " | Position: " <> T.pack (show (idx + 1)) <> "/" <> T.pack (show total)

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

-- | 키바인딩 도움말 렌더링 (Pure)
-- 현재 키바인딩 스타일에 맞는 단축키 안내 표시
renderKeyBindingHelp :: AppConfig -> Widget Name
renderKeyBindingHelp cfg =
  case configKeyBinding cfg of
    Emacs -> txt "ESC/C-g: Quit | Enter: Select | ↑↓/C-p/C-n: Navigate | C-u: Clear"
    Vim   -> txt "ESC/C-c: Quit | Enter: Select | ↑↓/C-k/C-j: Navigate | C-u: Clear"

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
