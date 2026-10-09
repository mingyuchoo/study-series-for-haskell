module Hfm.Application.Workflow (planInput) where

import Control.Monad (when)
import Control.Monad.Except (runExceptT)
import Control.Monad.State.Strict (get, modify, runStateT)
import qualified Data.Text as T
import Hfm.Application.Internal.Action
import Hfm.Application.Internal.Files
import Hfm.Application.Internal.Interaction
import Hfm.Application.Program
import Hfm.Application.State
import Hfm.Application.Status
import Hfm.Domain.Entry
import Hfm.Domain.Input
import Hfm.Domain.Selection (selectAt, selectStep, selectedElement)
import System.FilePath (takeDirectory, takeFileName)

-- Pure: produces a value or a typed request, without executing a port.
planInput :: Input -> AppState -> Program (AppState, Bool)
planInput input state = do
  (outcome, updated) <- runStateT (runExceptT (dispatch input)) state
  pure (updated, either (const True) (const False) outcome)

dispatch :: Input -> Action ()
dispatch (Resize w h) = modify (\s -> s { stTerminalSize = (w, h) })
dispatch (KeyPress (KFun 2) []) = modify toggleLanguage
dispatch (KeyPress (KFun 3) []) = modify toggleThemePicker
dispatch rawEvent = do
  st <- get
  let event = normalizeMeta rawEvent
  if stPendingCtrlX st
    then do
      modify (\s -> s { stPendingCtrlX = False })
      case event of
        KeyPress (KChar 'c') [MCtrl] -> halt
        KeyPress (KChar 'o') [] | stMode st == Browse && stThemePicker st == Nothing -> switchPanel
        KeyPress (KChar 'f') [MCtrl] | stMode st == Browse && stThemePicker st == Nothing -> enterSelected
        KeyPress (KChar 'k') [] -> cancelMode
        KeyPress (KChar 'g') [MCtrl] -> pure ()
        KeyPress KEsc [] -> pure ()
        _ -> modify (\s -> s { stStatus = UnknownCommand })
    else case event of
      KeyPress (KChar 'x') [MCtrl] -> modify (\s -> s { stPendingCtrlX = True })
      KeyPress (KChar 'g') [MCtrl] -> cancelMode
      _ -> case stThemePicker st of
        Just _ -> themePickerEvent event
        Nothing -> case stMode st of
          Browse -> browseEvent event
          Search -> searchEvent event
          Prompt op value -> promptEvent op value event
          ConfirmDelete -> confirmEvent event
          ViewFile path content offset -> viewEvent path content offset event


themePickerEvent :: Input -> Action ()
themePickerEvent event = case event of
  KeyPress KEsc [] -> modify (\s -> s { stThemePicker = Nothing })
  KeyPress KEnter [] -> modify $ \s -> case stThemePicker s >>= selectedElement of
    Just (_, theme) -> s { stTheme = theme, stThemePicker = Nothing }
    Nothing -> s
  KeyPress KUp [] -> selectTheme (selectStep (-1))
  KeyPress KDown [] -> selectTheme (selectStep 1)
  KeyPress (KChar 'p') [MCtrl] -> selectTheme (selectStep (-1))
  KeyPress (KChar 'n') [MCtrl] -> selectTheme (selectStep 1)
  KeyPress KHome [] -> selectTheme (selectAt 0)
  KeyPress KEnd [] -> selectTheme (selectAt (-1))
  KeyPress (KChar '<') [MMeta] -> selectTheme (selectAt 0)
  KeyPress (KChar '>') [MMeta] -> selectTheme (selectAt (-1))
  KeyPress (KChar digit) [] | digit >= '1' && digit <= '8' -> selectTheme (selectAt (fromEnum digit - fromEnum '1'))
  _ -> pure ()
  where
    selectTheme change = modify (\s -> s { stThemePicker = change <$> stThemePicker s })

browseEvent :: Input -> Action ()
browseEvent event = do
  st <- get
  case event of
    KeyPress KUp [] -> modify (moveSelection False)
    KeyPress KDown [] -> modify (moveSelection True)
    KeyPress (KChar 'p') [MCtrl] -> modify (moveSelection False)
    KeyPress (KChar 'n') [MCtrl] -> modify (moveSelection True)
    KeyPress KPageUp [] -> modify (movePage False)
    KeyPress KPageDown [] -> modify (movePage True)
    KeyPress (KChar 'v') [MCtrl] -> modify (movePage True)
    KeyPress (KChar 'v') [MMeta] -> modify (movePage False)
    KeyPress (KChar '<') [MMeta] -> modify (moveBoundary False)
    KeyPress (KChar '>') [MMeta] -> modify (moveBoundary True)
    KeyPress KHome [] -> modify (moveBoundary False)
    KeyPress KEnd [] -> modify (moveBoundary True)
    KeyPress KEnter [] -> enterSelected
    KeyPress (KChar 'f') [] -> enterSelected
    KeyPress (KChar 's') [MCtrl] -> startSearch
    KeyPress (KChar 'r') [MCtrl] -> startSearch
    KeyPress (KChar 'g') [] -> refreshAll
    KeyPress (KChar 'o') [MMeta] -> modify (\s -> s { stShowHidden = not (stShowHidden s) }) >> refreshAll
    KeyPress (KChar 'v') [] -> case selectedEntry st of
      Just e | entryKind e `elem` [RegularFile, SymbolicLink] -> maybe (pure ()) openView (selectedPath st)
      _ -> pure ()
    KeyPress (KChar 'C') [] -> startPrompt Copy
    KeyPress (KChar 'R') [] -> startPrompt Move
    KeyPress (KChar 'r') [] -> startPrompt Rename
    KeyPress (KChar 'e') [] -> case selectedEntry st of
      Just entry | entryKind entry == Directory -> startPrompt Rename
      _ -> openEditor
    KeyPress (KChar '!') [] -> startCommand
    KeyPress (KChar '!') [MMeta] -> startCommand
    KeyPress (KChar '+') [] -> modify (\s -> s { stMode = Prompt Mkdir "", stInputCursor = 0 })
    KeyPress (KChar 'D') [] -> when (selectedPath st /= Nothing) $ modify (\s -> s { stMode = ConfirmDelete })
    KeyPress (KChar '^') [] -> changeDir (takeDirectory (panelPath (activePanel st))) (Just (takeFileName (panelPath (activePanel st))))
    _ -> pure ()
  where
    startSearch = modify (\s -> s { stMode = Search, stInputCursor = T.length (panelSearch (activePanel s)) })
    startCommand = modify (\s -> s { stMode = Prompt Command "", stInputCursor = 0 })
