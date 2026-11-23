module Hfm.Application.Workflow (planInput) where

import           Data.Maybe                           (isJust, isNothing)
import qualified Data.Text                            as T

import           Hfm.Application.Internal.Files
import           Hfm.Application.Internal.Interaction
import           Hfm.Application.Internal.Navigation  (enterSelected, goToParent, previewSelected)
import           Hfm.Application.Internal.PanelRefresh (refreshAll, toggleHidden)
import           Hfm.Application.Internal.Process     (openEditor)
import           Hfm.Application.Internal.Settings    (persistSettings, startEditorPrompt, themePickerEvent)
import           Hfm.Application.Program
import           Hfm.Application.State
import           Hfm.Application.Status
import           Hfm.Domain.Entry
import           Hfm.Domain.Input

planInput :: Input -> AppState -> Program (AppState, Lifecycle)
planInput (Resize width height) state = continue (state { stTerminalSize = (width, height) })
planInput (KeyPress (KFun 2) []) state = persistSettings state (toggleLanguage state)
planInput (KeyPress (KFun 3) []) state = continue (toggleThemePicker state)
planInput (KeyPress (KFun 4) []) state = continue $
  if browsing state then startEditorPrompt state else state
planInput rawEvent state = case stKeySequence state of
  ControlXPrefix -> prefixEvent (normalizeMeta rawEvent) (state { stKeySequence = DirectInput })
  DirectInput -> case normalizeMeta rawEvent of
    KeyPress (KChar 'x') [MCtrl] -> continue (state { stKeySequence = ControlXPrefix })
    KeyPress (KChar 'g') [MCtrl] -> continue (cancelMode state)
    event -> case stThemePicker state of
      Just _ -> themePickerEvent event state
      Nothing -> case stMode state of
        Browse -> browseEvent event state
        Search -> continue (searchEvent event state)
        Prompt operation value -> promptEvent operation value event state
        EditorPrompt value -> editorPromptEvent value event state
        ConfirmDelete -> confirmEvent event state
        ViewFile path content offset -> continue (viewEvent path content offset event state)

browsing :: AppState -> Bool
browsing state = stMode state == Browse && isNothing (stThemePicker state)

prefixEvent :: Input -> AppState -> Program (AppState, Lifecycle)
prefixEvent event state = case event of
  KeyPress (KChar 'c') [MCtrl] -> Done (state, Quit)
  KeyPress (KChar 'o') [] | browsing state -> continue (switchPanel state)
  KeyPress (KChar 'f') [MCtrl] | browsing state -> enterSelected state
  KeyPress (KChar 'k') [] -> continue (cancelMode state)
  KeyPress (KChar 'g') [MCtrl] -> continue state
  KeyPress KEsc [] -> continue state
  _ -> continue (state { stStatus = UnknownCommand })

browseEvent :: Input -> AppState -> Program (AppState, Lifecycle)
browseEvent event state = case event of
  KeyPress KUp [] -> continue (moveSelection False state)
  KeyPress KDown [] -> continue (moveSelection True state)
  KeyPress (KChar 'p') [MCtrl] -> continue (moveSelection False state)
  KeyPress (KChar 'n') [MCtrl] -> continue (moveSelection True state)
  KeyPress KPageUp [] -> continue (movePage False state)
  KeyPress KPageDown [] -> continue (movePage True state)
  KeyPress (KChar 'v') [MCtrl] -> continue (movePage True state)
  KeyPress (KChar 'v') [MMeta] -> continue (movePage False state)
  KeyPress (KChar '<') [MMeta] -> continue (moveBoundary False state)
  KeyPress (KChar '>') [MMeta] -> continue (moveBoundary True state)
  KeyPress KHome [] -> continue (moveBoundary False state)
  KeyPress KEnd [] -> continue (moveBoundary True state)
  KeyPress KEnter [] -> enterSelected state
  KeyPress (KChar 'f') [] -> enterSelected state
  KeyPress (KChar 's') [MCtrl] -> startSearch
  KeyPress (KChar 'r') [MCtrl] -> startSearch
  KeyPress (KChar 'g') [] -> refreshAll state
  KeyPress (KChar 'o') [MMeta] -> toggleHidden state
  KeyPress (KChar 'v') [] -> previewSelected state
  KeyPress (KChar 'C') [] -> continue (startPrompt Copy state)
  KeyPress (KChar 'R') [] -> continue (startPrompt Move state)
  KeyPress (KChar 'r') [] -> continue (startPrompt Rename state)
  KeyPress (KChar 'e') [] -> case selectedEntry state of
    Just entry | entryKind entry == Directory -> continue (startPrompt Rename state)
    _ -> openEditor state
  KeyPress (KChar '!') [] -> startCommand
  KeyPress (KChar '!') [MMeta] -> startCommand
  KeyPress (KChar '+') [] -> continue (state { stMode = Prompt Mkdir "", stInputCursor = 0 })
  KeyPress (KChar 'D') [] | isJust (selectedPath state) -> continue (state { stMode = ConfirmDelete })
  KeyPress (KChar '^') [] -> goToParent state
  _ -> continue state
  where
    startSearch = continue (state { stMode = Search, stInputCursor = T.length (panelSearch (activePanel state)) })
    startCommand = continue (state { stMode = Prompt Command "", stInputCursor = 0 })
