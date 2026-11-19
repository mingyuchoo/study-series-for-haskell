{-# LANGUAGE OverloadedStrings #-}

module UI
  ( drawUI
  , formatInfoText
  , renderWarningUI
  ) where

import Brick
import Brick.Widgets.Border
import Brick.Widgets.Center
import Brick.Widgets.List

import Config (KeyBindingStyle (..))

import Data.Text qualified as T
import Data.Vector qualified as Vec

import Event (formatPreviewError)
import Flow ((<|))
import Fzh.Domain.Session (PreviewState (..), browserPreview, sessionBrowser)

import SyntaxHighlight (renderPreviewContent)

import Types
  ( AppConfig (..)
  , AppState
  , Name
  , contentHeight
  , isTerminalSizeSufficient
  , minTerminalHeight
  , minTerminalWidth
  , previewWidth
  , resultListWidth
  , stConfig
  , stFilteredList
  , stSearchQuery
  , stSession
  , stTerminalSize
  )

drawUI :: AppState -> [Widget Name]
drawUI st = [ui]
  where
    (termWidth, termHeight) = stTerminalSize st
    cfg = stConfig st

    ui =
      if isTerminalSizeSufficient (termWidth, termHeight)
        then renderNormalUI st termWidth termHeight cfg
        else renderWarningUI st

renderNormalUI :: AppState -> Int -> Int -> AppConfig -> Widget Name
renderNormalUI st termWidth termHeight cfg =
  vBox
    [ renderSearchBox st termWidth
    , hBox
        [ vLimit (contentHeight termHeight)
            <| hLimit (resultListWidth termWidth)
            <| renderResultList cfg st
        , vLimit (contentHeight termHeight)
            <| hLimit (previewWidth termWidth)
            <| renderFilePreview cfg st
        ]
    , renderInfo cfg st termWidth
    , padTop (Pad 1) <| hCenter <| renderKeyBindingHelp cfg
    ]

renderSearchBox :: AppState -> Int -> Widget Name
renderSearchBox st termWidth =
  hLimit termWidth
    <| borderWithLabel (txt "Search")
    <| padLeftRight 1
    <| txt (stSearchQuery st <> "_")

renderResultList :: AppConfig -> AppState -> Widget Name
renderResultList _cfg st =
  borderWithLabel (txt "Results") <|
    renderList drawItem True (stFilteredList st)
  where
    drawItem _ item = txt ("  " <> item)

formatInfoText :: Int -> Maybe Int -> T.Text
formatInfoText total Nothing = "Items: " <> T.pack (show total)
formatInfoText total (Just idx) =
  "Items: "
    <> T.pack (show total)
    <> " | Position: "
    <> T.pack (show (idx + 1))
    <> "/"
    <> T.pack (show total)

renderInfo :: AppConfig -> AppState -> Int -> Widget Name
renderInfo _cfg st termWidth =
  hLimit termWidth
    <| border
    <| padLeftRight 1
    <| txt
    <| formatInfoText totalItems selectedIdx
  where
    totalItems = Vec.length <| listElements <| stFilteredList st
    selectedIdx = fst <$> listSelectedElement (stFilteredList st)

renderFilePreview :: AppConfig -> AppState -> Widget Name
renderFilePreview _cfg st =
  borderWithLabel (txt "Preview") <|
    padBottom Max <|
      padRight Max <|
        padLeftRight 1 <|
          case browserPreview (sessionBrowser (stSession st)) of
            NoPreview -> txt "No file selected"
            Loading _ -> txt "Loading..."
            Failed _ problem -> txt (formatPreviewError problem)
            Loaded path content -> renderPreviewContent path content

renderKeyBindingHelp :: AppConfig -> Widget Name
renderKeyBindingHelp cfg =
  case configKeyBinding cfg of
    Emacs -> txt "ESC/C-g: Quit | Enter: Select | ↑↓/C-p/C-n: Navigate | C-u: Clear"
    Vim -> txt "ESC/C-c: Quit | Enter: Select | ↑↓/C-k/C-j: Navigate | C-u: Clear"

renderWarningUI :: AppState -> Widget Name
renderWarningUI st =
  let (w, h) = stTerminalSize st
      warning =
        vCenter
          <| hCenter
          <| vBox
            [ txt "⚠️  터미널 크기가 너무 작습니다"
            , txt ""
            , txt <| "현재: " <> T.pack (show w) <> "x" <> T.pack (show h)
            , txt <| "최소: " <> T.pack (show minTerminalWidth) <> "x" <> T.pack (show minTerminalHeight)
            , txt ""
            , txt "터미널 크기를 조정해주세요"
            ]
   in border warning
