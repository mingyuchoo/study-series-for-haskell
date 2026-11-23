module Hfm.Application.Internal.Interaction
  ( cancelMode, moveBoundary, switchPanel, movePage
  , searchEvent, promptEvent, editorPromptEvent, confirmEvent, viewEvent
  ) where

import qualified Data.Text                        as T

import           Hfm.Application.Internal.Files   (deleteSelected,
                                                   runFileOperation)
import           Hfm.Application.Internal.Process (executeCommand)
import           Hfm.Application.Internal.Settings (confirmEditor)
import           Hfm.Application.Program
import           Hfm.Application.State
import           Hfm.Application.Status
import           Hfm.Domain.Editor                (editText)
import           Hfm.Domain.Input
import           Hfm.Domain.Selection             (selectAt)

cancelMode :: AppState -> AppState
cancelMode state = case stThemePicker state of
  Just _ -> state { stThemePicker = Nothing }
  Nothing -> let cleared = if stMode state == Search || stMode state == Browse
                            then setSearch "" state else state
             in cleared { stMode = Browse, stInputCursor = 0, stKeySequence = DirectInput
                        , stStatus = Cancelled }

moveBoundary :: Bool -> AppState -> AppState
moveBoundary end state =
  let panel = activePanel state
  in replaceActivePanel (panel { panelEntries = selectAt (if end then -1 else 0) (panelEntries panel) }) state

switchPanel :: AppState -> AppState
switchPanel state = state { stActive = case stActive state of
  LeftSide  -> RightSide
  RightSide -> LeftSide }

movePage :: Bool -> AppState -> AppState
movePage down state = iterate (moveSelection down) state !! max 1 (snd (stTerminalSize state) - 6)

setSearch :: T.Text -> AppState -> AppState
setSearch query state =
  let panel = activePanel state
      updated = refreshPanel (panelAll panel) Nothing (panel { panelSearch = query })
  in replaceActivePanel updated state

searchEvent :: Input -> AppState -> AppState
searchEvent event state = case event of
  KeyPress KEsc [] -> cancel
  KeyPress (KChar 'g') [MCtrl] -> cancel
  KeyPress KEnter [] -> state { stMode = Browse }
  KeyPress KUp [] -> moveSelection False state
  KeyPress KDown [] -> moveSelection True state
  KeyPress (KChar 'v') [MCtrl] -> movePage True state
  KeyPress (KChar 'v') [MMeta] -> movePage False state
  KeyPress (KChar 'p') [MCtrl] -> moveSelection False state
  KeyPress (KChar 'n') [MCtrl] -> moveSelection True state
  KeyPress (KChar 's') [MCtrl] -> moveSelection True state
  KeyPress (KChar 'r') [MCtrl] -> moveSelection False state
  KeyPress KPageUp [] -> movePage False state
  KeyPress KPageDown [] -> movePage True state
  KeyPress (KChar '<') [MMeta] -> moveBoundary False state
  KeyPress (KChar '>') [MMeta] -> moveBoundary True state
  _ -> case editText event (panelSearch (activePanel state)) (stInputCursor state) of
    Just (value, cursor) -> (setSearch value state) { stInputCursor = cursor }
    Nothing              -> state
  where
    cancel = (setSearch "" state) { stMode = Browse, stInputCursor = 0 }

promptEvent :: Operation -> T.Text -> Input -> AppState -> Program (AppState, Lifecycle)
promptEvent operation value event state = case event of
  KeyPress KEsc [] -> continue (state { stMode = Browse })
  KeyPress (KChar 'g') [MCtrl] -> continue (state { stMode = Browse })
  KeyPress KEnter [] -> case operation of
    Command -> executeCommand value state
    _       -> runFileOperation operation value state
  _ -> continue $ case editText event value (stInputCursor state) of
    Just (newValue, cursor) -> state { stMode = Prompt operation newValue, stInputCursor = cursor }
    Nothing -> state

editorPromptEvent :: T.Text -> Input -> AppState -> Program (AppState, Lifecycle)
editorPromptEvent value event state = case event of
  KeyPress KEsc [] -> continue (cancelMode state)
  KeyPress KEnter [] -> confirmEditor value state
  _ -> continue $ case editText event value (stInputCursor state) of
    Just (newValue, cursor) -> state { stMode = EditorPrompt newValue, stInputCursor = cursor }
    Nothing -> state

confirmEvent :: Input -> AppState -> Program (AppState, Lifecycle)
confirmEvent event state = case event of
  KeyPress (KChar key) [] | key `elem` ['y', 'Y'] -> deleteSelected state
  KeyPress _ _ -> continue (state { stMode = Browse, stStatus = DeletionCancelled })
  _ -> continue state

viewEvent :: FilePath -> T.Text -> Int -> Input -> AppState -> AppState
viewEvent path content offset event state = case event of
  KeyPress KEsc []             -> close
  KeyPress (KChar 'g') [MCtrl] -> close
  KeyPress (KChar 'q') []      -> close
  KeyPress KUp []              -> scroll (-1)
  KeyPress KDown []            -> scroll 1
  KeyPress KPageUp []          -> scrollPage (-1)
  KeyPress KPageDown []        -> scrollPage 1
  KeyPress (KChar 'p') [MCtrl] -> scroll (-1)
  KeyPress (KChar 'n') [MCtrl] -> scroll 1
  KeyPress (KChar 'v') [MCtrl] -> scrollPage 1
  KeyPress (KChar 'v') [MMeta] -> scrollPage (-1)
  KeyPress (KChar '<') [MMeta] -> scrollTo 0
  KeyPress (KChar '>') [MMeta] -> scrollTo (length (T.lines content))
  KeyPress KHome []            -> scrollTo 0
  KeyPress KEnd []             -> scrollTo (length (T.lines content))
  _                            -> state
  where
    close = state { stMode = Browse }
    scrollTo target = state { stMode = ViewFile path content (clampViewerOffset state content target) }
    scroll step = scrollTo (offset + step)
    scrollPage direction = scroll (direction * max 1 (viewerContentHeight state))
