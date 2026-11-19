module Hfm.Application.Internal.Process (openEditor, executeCommand) where

import qualified Data.Text               as T

import           Hfm.Application.Program
import           Hfm.Application.State
import           Hfm.Application.Status
import           Hfm.Domain.Config       (settingsEditor)
import           Hfm.Domain.Entry

openEditor :: AppState -> Program (AppState, Lifecycle)
openEditor state = case (selectedEntry state, selectedPath state) of
  (Just entry, Just path) | entryKind entry `elem` [RegularFile, SymbolicLink] ->
    Await (EditFile (settingsEditor (currentSettings state)) (panelPath (activePanel state)) path)
      (Working state (CompletingProcess EditorProcess))
  _ -> continue state

executeCommand :: T.Text -> AppState -> Program (AppState, Lifecycle)
executeCommand raw state
  | T.null (T.strip raw) || T.any (== '\0') raw = continue (state { stStatus = InvalidCommand })
  | otherwise = Await (RunCommand (panelPath (activePanel state)) raw)
      (Working state (CompletingProcess ShellProcess))
