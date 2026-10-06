{-# LANGUAGE OverloadedStrings #-}

module UI (drawUI) where

import Brick
import Brick.Widgets.Border (border, borderWithLabel)
import Brick.Widgets.List (listElements, listSelectedElement, renderList)
import Config (KeyBindingStyle (..))
import qualified Data.Text as T
import qualified Data.Vector as Vec
import FileManager (Entry (..), EntryKind (..))
import Types

-- The main screen deliberately uses only a few fixed rows, leaving the rest to the lists.
drawUI :: AppState -> [Widget Name]
drawUI st = [case stMode st of
  ViewFile path content offset -> renderViewer st path content offset
  _ -> renderManager st]

renderManager :: AppState -> Widget Name
renderManager st = vBox
  [ withAttr (attrName "header") $ padLeftRight 1 $ txt "hfm  |  파일 관리자"
  , renderInput st
  , hBox [renderPanel st LeftSide (stLeft st) leftWidth, renderPanel st RightSide (stRight st) rightWidth]
  , renderStatus st
  , withAttr (attrName "keys") $ padLeftRight 1 $ txt $ navigationHelp st
  ]
  where
    width = fst (stTerminalSize st)
    leftWidth = max 1 (width `div` 2)
    rightWidth = max 1 (width - leftWidth)

navigationHelp :: AppState -> T.Text
navigationHelp st
  | stPendingCtrlX st = "C-x: C-c 종료  o 패널  C-g 취소"
  | otherwise = case configKeyBinding (stConfig st) of
      Emacs -> "C-p/n 이동  v 보기  C 복사  R 이동  + 폴더  D 삭제  . 숨김  q 종료"
      Vim -> "j/k 이동  v 보기  C 복사  R 이동  + 폴더  D 삭제  . 숨김  q 종료"

renderInput :: AppState -> Widget Name
renderInput st = withAttr (attrName "input") $ padLeftRight 1 $ txt $ case stMode st of
  Browse -> case configKeyBinding (stConfig st) of
    Emacs -> "C-s 검색  Enter 열기  ^ 상위  g 새로고침  C-x 명령"
    Vim -> "/ 검색  Enter 열기  ^ 상위  g 새로고침"
  Search -> "검색: " <> markInputCursor st (panelSearch (activePanel st)) <> "  (Enter 적용, C-g 취소)"
  Prompt Copy value -> "복사 대상: " <> markInputCursor st value <> "  (Enter 실행, C-g 취소)"
  Prompt Move value -> "이동/새 이름: " <> markInputCursor st value <> "  (Enter 실행, C-g 취소)"
  Prompt Mkdir value -> "새 폴더: " <> markInputCursor st value <> "  (Enter 생성, C-g 취소)"
  ConfirmDelete -> "삭제 확인: " <> maybe "" (T.pack . entryName) (selectedEntry st) <> "  (y 삭제, 다른 키 취소)"
  ViewFile {} -> ""

markInputCursor :: AppState -> T.Text -> T.Text
markInputCursor st value =
  let cursor = stInputCursor st
  in T.take cursor value <> "_" <> T.drop cursor value

renderPanel :: AppState -> Side -> Panel -> Int -> Widget Name
renderPanel st side panel width =
  hLimit width $ vLimit (max 1 (snd (stTerminalSize st) - 4)) $
    withAttr (attrName (if stActive st == side then "active" else "inactive")) $
      borderWithLabel (txt (T.pack (panelPath panel))) $
        renderList drawEntry (stActive st == side) (panelEntries panel)
  where
    drawEntry isSelected entry =
      let prefix = case entryKind entry of
            Parent -> "↑ "
            Directory -> "/ "
            SymbolicLink -> "@ "
            RegularFile -> "  "
            Special -> "! "
          suffix = case entryKind entry of
            RegularFile -> "  "
            Special -> "! " <> T.pack (show (entrySize entry))
            _ -> ""
      in withAttr (attrName (if isSelected && stActive st == side then "selected" else if isSelected then "selectedInactive" else if stActive st == side then "active" else "inactive")) $
           txt (prefix <> T.pack (entryName entry) <> suffix)

renderStatus :: AppState -> Widget Name
renderStatus st = withAttr (attrName "status") $ padLeftRight 1 $ txt $ 
  let panel = activePanel st
      count = Vec.length (listElements (panelEntries panel))
      position = maybe 0 ((+ 1) . fst) (listSelectedElement (panelEntries panel))
      hidden = if stShowHidden st then "보임" else "숨김"
  in T.pack (show position) <> "/" <> T.pack (show count) <> "  숨김 파일: " <> hidden <> "  |  " <> stStatus st

renderViewer :: AppState -> FilePath -> T.Text -> Int -> Widget Name
renderViewer st path content offset =
  vBox
    [ withAttr (attrName "header") $ padRight Max $ padLeftRight 1 $ txt ("보기: " <> T.pack path)
    , vLimit (max 1 (height - 2)) $ border $ padRight Max $ padBottom Max $ vBox $
        map txt $ take (max 1 (height - 4)) $ drop offset (T.lines content)
    , withAttr (attrName "keys") $ padRight Max $ padLeftRight 1 $ txt "C-p/n 스크롤  C-v/M-v 페이지  C-g 닫기  |  최대 64 KiB 표시"
    ]
  where height = snd (stTerminalSize st)
