{-# LANGUAGE OverloadedStrings #-}

module Hfm.Tui.UI (drawUI) where

import Brick
import Brick.Widgets.Border (border, borderWithLabel)
import qualified Brick.Widgets.List
import Brick.Widgets.List (list, listMoveTo, renderList)
import qualified Data.Text as T
import qualified Data.Vector as Vec
import Brick.Widgets.Center (centerLayer)
import Hfm.Domain.Theme (themeName)
import Hfm.Domain.Entry (Entry (..), EntryKind (..))
import Hfm.Tui.I18n (translate, renderStatus)
import Hfm.Tui.Name
import Hfm.Application.State
import Hfm.Domain.Selection
import Hfm.Tui.Layout (viewerHelpLines, prepareLayout)

-- The main screen deliberately uses only a few fixed rows, leaving the rest to the lists.
drawUI :: AppState -> [Widget Name]
drawUI state =
  let st = prepareLayout state
      screen = withAttr (attrName "default") $ padRight Max $ padBottom Max $ case stMode st of
        ViewFile path content offset -> renderViewer st path content offset
        _ -> renderManager st
  in case stThemePicker st of
    Just choices -> [renderThemePicker st choices, screen]
    Nothing -> [screen]

renderThemePicker :: AppState -> Selection Theme -> Widget Name
renderThemePicker st choices = centerLayer $
  hLimit (max 1 (min 54 (fst (stTerminalSize st) - 2))) $
  vLimit (max 1 (min 12 (snd (stTerminalSize st) - 2))) $
  withAttr (attrName "active") $
  borderWithLabel (txt (translate (stLanguage st) "테마 선택")) $
  vBox
    [ renderList drawTheme True entries
    , withAttr (attrName "input") $ txtWrap (translate (stLanguage st) "미리보기: " <> maybe "" (themeName . snd) (selectedElement choices))
    , withAttr (attrName "keys") $ txtWrap help
    ]
  where
    entries = maybe base (`listMoveTo` base) (selectionIndex choices)
    base = list ThemeList (Vec.imap (\i theme -> (i, theme)) (selectionItems choices)) 1
    drawTheme selected (i, theme) = withAttr (attrName (if selected then "selected" else "active")) $
      txt (T.pack (show (i + 1)) <> " " <> (if theme == stTheme st then "* " else "  ") <> themeName theme)
    help
      | stPendingCtrlX st = translate (stLanguage st) "C-x: C-c 종료  k 닫기  C-g 명령 취소"
      | otherwise = translate (stLanguage st) "↑/↓ C-p/n 이동  1-6 선택  RET 적용  Esc/C-g 취소"

renderManager :: AppState -> Widget Name
renderManager st = vBox
  [ withAttr (attrName "header") $ padLeftRight 1 $ txt (translate (stLanguage st) "hfm  |  파일 관리자" <> "  |  " <> translate (stLanguage st) "F2 한국어" <> "  |  " <> translate (stLanguage st) "F3 테마")
  , renderInput st
  , hBox [renderPanel st LeftSide (stLeft st) leftWidth, renderPanel st RightSide (stRight st) rightWidth]
  , renderStatusBar st
  , withAttr (attrName "keys") $ padLeftRight 1 $ txt $ navigationHelp st
  ]
  where
    width = fst (stTerminalSize st)
    leftWidth = max 1 (width `div` 2)
    rightWidth = max 1 (width - leftWidth)

navigationHelp :: AppState -> T.Text
navigationHelp st
  | stPendingCtrlX st = if stMode st == Browse
      then translate (stLanguage st) "C-x: C-c 종료  o 패널  C-f 열기  k 닫기  C-g 취소"
      else translate (stLanguage st) "C-x: C-c 종료  k 닫기  C-g 명령 취소"
  | otherwise = case stMode st of
      Search -> translate (stLanguage st) "C-s/r 다음/이전  C-p/n 이동  C-v/M-v 페이지  C-g 취소"
      Prompt {} -> translate (stLanguage st) "C-a/e 처음/끝  C-b/f 문자  M-b/f 단어  C-k/M-d 삭제"
      ConfirmDelete -> translate (stLanguage st) "y 삭제  n/C-g 취소"
      _ -> translate (stLanguage st) "C-p/n 이동  C-v/M-v 페이지  M-</> 처음/끝  C-x o 패널  C-x C-c 종료"

renderInput :: AppState -> Widget Name
renderInput st = withAttr (attrName "input") $ padLeftRight 1 $ txt $ case stMode st of
  Browse -> translate (stLanguage st) "C-s/r 검색  RET 열기  ^ 상위  v 보기  C 복사  R 이동  + 폴더  D 삭제  M-o 숨김  g 갱신"
  Search -> translate (stLanguage st) "검색: " <> markInputCursor st (panelSearch (activePanel st)) <> translate (stLanguage st) "  (RET 적용, C-g 취소)"
  Prompt Copy value -> translate (stLanguage st) "복사 대상: " <> markInputCursor st value <> translate (stLanguage st) "  (RET 실행, C-g 취소)"
  Prompt Move value -> translate (stLanguage st) "이동/새 이름: " <> markInputCursor st value <> translate (stLanguage st) "  (RET 실행, C-g 취소)"
  Prompt Mkdir value -> translate (stLanguage st) "새 폴더: " <> markInputCursor st value <> translate (stLanguage st) "  (RET 생성, C-g 취소)"
  ConfirmDelete -> translate (stLanguage st) "삭제 확인: " <> maybe "" (T.pack . entryName) (selectedEntry st) <> translate (stLanguage st) "  (y 삭제, 다른 키 취소)"
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
        renderList drawEntry (stActive st == side) (brickList side panel)
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

-- Brick lists are presentation values, reconstructed from the pure selection.
brickList :: Side -> Panel -> Brick.Widgets.List.List Name Entry
brickList side panel =
  let selected = panelEntries panel
      entries = list (if side == LeftSide then LeftList else RightList) (selectionItems selected) 1
  in maybe entries (`listMoveTo` entries) (selectionIndex selected)

renderStatusBar :: AppState -> Widget Name
renderStatusBar st = withAttr (attrName "status") $ padLeftRight 1 $ txt $
  let panel = activePanel st
      count = Vec.length (selectionItems (panelEntries panel))
      position = maybe 0 ((+ 1) . fst) (selectedElement (panelEntries panel))
      hidden = if stShowHidden st then translate (stLanguage st) "보임" else translate (stLanguage st) "숨김"
  in T.pack (show position) <> "/" <> T.pack (show count) <> translate (stLanguage st) "  숨김 파일: " <> hidden <> "  |  " <> renderStatus (stLanguage st) (stStatus st) <> "  |  " <> themeName (stTheme st)

renderViewer :: AppState -> FilePath -> T.Text -> Int -> Widget Name
renderViewer st path content offset =
  vBox
    [ withAttr (attrName "header") $ padRight Max $ padLeftRight 1 $ txt (translate (stLanguage st) "F2 한국어" <> "  |  " <> translate (stLanguage st) "F3 테마" <> "  |  " <> translate (stLanguage st) "보기: " <> T.pack path)
    , vLimit bodyHeight $ border $ padRight Max $ padBottom Max $ vBox $
        map renderLine $ take (viewerContentHeight st) $ drop (clampViewerOffset st content offset) (T.lines content)
    , vLimit (max 0 (height - 1)) $ withAttr (attrName "keys") $ padRight Max $ padLeftRight 1 $
        vBox (map txt helpLines)
    ]
  where
    height = snd (stTerminalSize st)
    helpLines = viewerHelpLines st
    bodyHeight = max 0 (height - 1 - length helpLines)
    -- Empty lines must occupy a row, just like nonempty file lines.
    renderLine line = txt (if T.null line then " " else line)
