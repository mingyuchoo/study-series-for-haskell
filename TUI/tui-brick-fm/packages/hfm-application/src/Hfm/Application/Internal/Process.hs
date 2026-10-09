module Hfm.Application.Internal.Process (openEditor, executeCommand) where

import Control.Monad.State.Strict (get, modify)
import qualified Data.Text as T
import Hfm.Application.Internal.Action
import Hfm.Application.Internal.Files (finish)
import Hfm.Application.Program
import Hfm.Application.State
import Hfm.Application.Status
import Hfm.Domain.Entry
import Hfm.Domain.Config (settingsEditor)

openEditor :: Action ()
openEditor = do
  st <- get
  case (selectedEntry st, selectedPath st) of
    (Just entry, Just path) | entryKind entry `elem` [RegularFile, SymbolicLink] ->
      attempt (request (EditFile (settingsEditor (currentSettings st)) (panelPath (activePanel st)) path)) (finish . EditorFinished)
    _ -> pure ()

executeCommand :: T.Text -> Action ()
executeCommand raw = do
  st <- get
  if T.null (T.strip raw) || T.any (== '\0') raw
    then modify (\s -> s { stStatus = InvalidCommand })
    else attempt (request (RunCommand (panelPath (activePanel st)) raw)) (finish . CommandFinished)
