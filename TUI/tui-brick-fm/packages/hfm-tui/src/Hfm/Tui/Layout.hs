module Hfm.Tui.Layout (viewerHelpLines, prepareLayout) where

import Brick (textWidth)
import qualified Data.Text as T
import Hfm.Application.State
import Hfm.Tui.I18n (translate)

viewerHelpLines :: AppState -> [T.Text]
viewerHelpLines st = case T.words (viewerHelpText st) of
  [] -> []
  word : rest -> wrap word rest
  where
    width = max 1 (fst (stTerminalSize st) - 2)
    wrap line [] = [line]
    wrap line (word : rest)
      | textWidth (line <> " " <> word) <= width = wrap (line <> " " <> word) rest
      | otherwise = line : wrap word rest

-- Presentation owns display-cell measurement; the application receives only rows.
prepareLayout :: AppState -> AppState
prepareLayout st =
  let measured = st { stViewerFooterRows = length (viewerHelpLines st) }
  in case stMode measured of
    ViewFile path content offset -> measured { stMode = ViewFile path content (clampViewerOffset measured content offset) }
    _ -> measured

viewerHelpText :: AppState -> T.Text
viewerHelpText st
  | stPendingCtrlX st = translate (stLanguage st) "C-x: C-c 종료  k 닫기  C-g 명령 취소"
  | otherwise = translate (stLanguage st) "C-p/n 스크롤  C-v/M-v 페이지  M-</> 처음/끝  C-g/C-x k 닫기  C-x C-c 종료"

