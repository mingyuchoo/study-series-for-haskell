module Hfm.Application.Internal.Interaction
  ( cancelMode, moveBoundary, switchPanel, movePage, startPrompt
  , searchEvent, promptEvent, editorPromptEvent, confirmEvent, viewEvent
  ) where

import Control.Monad (when)
import Control.Monad.State.Strict (get, modify)
import qualified Data.Text as T
import Hfm.Application.Internal.Action
import Hfm.Application.Internal.Files (runFileOperation, deleteSelected)
import Hfm.Application.Internal.Process (executeCommand)
import Hfm.Application.State
import Hfm.Application.Status
import Hfm.Domain.Editor (editText)
import Hfm.Domain.Config (Settings (..), validEditor)
import Hfm.Domain.Entry
import Hfm.Domain.Input
import Hfm.Domain.Selection (selectAt)

cancelMode :: Action ()
cancelMode = do
  st <- get
  case stThemePicker st of
    Just _ -> modify (\s -> s { stThemePicker = Nothing })
    Nothing -> do
      when (stMode st == Search || stMode st == Browse) (setSearch "")
      modify (\s -> s { stMode = Browse, stInputCursor = 0, stPendingCtrlX = False
                       , stStatus = Cancelled })

moveBoundary :: Bool -> AppState -> AppState
moveBoundary end st =
  let panel = activePanel st
  in replaceActivePanel (panel { panelEntries = selectAt (if end then -1 else 0) (panelEntries panel) }) st

switchPanel :: Action ()
switchPanel = modify (\s -> s { stActive = if stActive s == LeftSide then RightSide else LeftSide })

movePage :: Bool -> AppState -> AppState
movePage down st = iterate (moveSelection down) st !! max 1 (snd (stTerminalSize st) - 6)

startPrompt :: Operation -> Action ()
startPrompt op = do
  st <- get
  when (maybe False ((/= Special) . entryKind) (selectedEntry st) && selectedPath st /= Nothing) $ do
    let other = if stActive st == LeftSide then stRight st else stLeft st
    let value = T.pack (if op == Rename then maybe "" entryName (selectedEntry st) else panelPath other)
    modify (\s -> s { stMode = Prompt op value, stInputCursor = T.length value })

setSearch :: T.Text -> Action ()
setSearch query = modify $ \s ->
  let panel = activePanel s
      updated = refreshPanel (panelAll panel) Nothing (panel { panelSearch = query })
  in replaceActivePanel updated s

searchEvent :: Input -> Action ()
searchEvent event = case event of
  KeyPress KEsc [] -> cancel
  KeyPress (KChar 'g') [MCtrl] -> cancel
  KeyPress KEnter [] -> modify (\s -> s { stMode = Browse })
  KeyPress KUp [] -> modify (moveSelection False)
  KeyPress KDown [] -> modify (moveSelection True)
  KeyPress (KChar 'v') [MCtrl] -> modify (movePage True)
  KeyPress (KChar 'v') [MMeta] -> modify (movePage False)
  KeyPress (KChar 'p') [MCtrl] -> modify (moveSelection False)
  KeyPress (KChar 'n') [MCtrl] -> modify (moveSelection True)
  KeyPress (KChar 's') [MCtrl] -> modify (moveSelection True)
  KeyPress (KChar 'r') [MCtrl] -> modify (moveSelection False)
  KeyPress KPageUp [] -> modify (movePage False)
  KeyPress KPageDown [] -> modify (movePage True)
  KeyPress (KChar '<') [MMeta] -> modify (moveBoundary False)
  KeyPress (KChar '>') [MMeta] -> modify (moveBoundary True)
  _ -> do
    st <- get
    case editText event (panelSearch (activePanel st)) (stInputCursor st) of
      Just (value, cursor) -> setSearch value >> modify (\s -> s { stInputCursor = cursor })
      Nothing -> pure ()
  where
    cancel = setSearch "" >> modify (\s -> s { stMode = Browse, stInputCursor = 0 })

promptEvent :: Operation -> T.Text -> Input -> Action ()
promptEvent op value event = case event of
  KeyPress KEsc [] -> modify (\s -> s { stMode = Browse })
  KeyPress (KChar 'g') [MCtrl] -> modify (\s -> s { stMode = Browse })
  KeyPress KEnter [] -> case op of
    Command -> executeCommand value
    _ -> runFileOperation op value
  _ -> do
    st <- get
    case editText event value (stInputCursor st) of
      Just (newValue, cursor) -> modify (\s -> s { stMode = Prompt op newValue, stInputCursor = cursor })
      Nothing -> pure ()

editorPromptEvent :: T.Text -> Input -> Action ()
editorPromptEvent value event = case event of
  KeyPress KEsc [] -> cancelMode
  KeyPress KEnter []
    | not (validEditor value) -> modify (\s -> s { stStatus = InvalidEditor })
    | otherwise -> modify $ \s ->
        let executable = T.strip value
            settings = (currentSettings s)
              { settingsEditor = if T.null executable then Nothing else Just (T.unpack executable) }
        in (applySettings settings s) { stMode = Browse, stInputCursor = 0, stStatus = SettingsSaved }
  _ -> do
    st <- get
    case editText event value (stInputCursor st) of
      Just (newValue, cursor) -> modify (\s -> s { stMode = EditorPrompt newValue, stInputCursor = cursor })
      Nothing -> pure ()

confirmEvent :: Input -> Action ()
confirmEvent event = case event of
  KeyPress (KChar 'y') [] -> deleteSelected
  KeyPress (KChar 'Y') [] -> confirmEvent (KeyPress (KChar 'y') [])
  KeyPress _ _ -> modify (\s -> s { stMode = Browse, stStatus = DeletionCancelled })
  _ -> pure ()

viewEvent :: FilePath -> T.Text -> Int -> Input -> Action ()
viewEvent path content offset event = case event of
  KeyPress KEsc [] -> close
  KeyPress (KChar 'g') [MCtrl] -> close
  KeyPress (KChar 'q') [] -> close
  KeyPress KUp [] -> scroll (-1)
  KeyPress KDown [] -> scroll 1
  KeyPress KPageUp [] -> scrollPage (-1)
  KeyPress KPageDown [] -> scrollPage 1
  KeyPress (KChar 'p') [MCtrl] -> scroll (-1)
  KeyPress (KChar 'n') [MCtrl] -> scroll 1
  KeyPress (KChar 'v') [MCtrl] -> scrollPage 1
  KeyPress (KChar 'v') [MMeta] -> scrollPage (-1)
  KeyPress (KChar '<') [MMeta] -> scrollTo 0
  KeyPress (KChar '>') [MMeta] -> scrollTo (length (T.lines content))
  KeyPress KHome [] -> scrollTo 0
  KeyPress KEnd [] -> scrollTo (length (T.lines content))
  _ -> pure ()
  where
    close = modify (\s -> s { stMode = Browse })
    scrollTo target = modify (\s -> s { stMode = ViewFile path content (clampViewerOffset s content target) })
    scroll step = scrollTo (offset + step)
    scrollPage direction = do
      st <- get
      scroll (direction * max 1 (viewerContentHeight st))
