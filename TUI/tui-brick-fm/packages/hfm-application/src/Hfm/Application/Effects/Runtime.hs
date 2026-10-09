{-# LANGUAGE GADTs #-}

module Hfm.Application.Effects.Runtime (handleInput, runProgram) where

import Hfm.Application.Effects.Ports
import Hfm.Application.Error (FileError)
import Hfm.Application.Program
import Hfm.Application.State (AppState (..), Mode (..), currentSettings, applySettings)
import Hfm.Application.Status (Status (SettingsSaveFailed, SettingsSaved))
import Hfm.Domain.Config (Settings)
import Hfm.Application.Workflow (planInput)
import Hfm.Domain.Input (Input)

-- Effectful shell: the only application module that executes supplied ports.
runProgram :: forall m a. Monad m => FileSystem m -> Processes m -> Program a -> m a
runProgram _ _ (Done value) = pure value
runProgram files processes (Await effect resume) = do
  result <- execute effect
  runProgram files processes (resume result)
  where
    execute :: Request b -> m (Either FileError b)
    execute (ReadEntries hidden path) = readEntries files hidden path
    execute (CanonicalizePath path) = canonicalizePath files path
    execute (DirectoryExists path) = doesDirectoryExist files path
    execute (ReadPreview path) = readPreview files path
    execute (CopyEntry source target) = copyEntry files source target
    execute (MoveEntry source target) = moveEntry files source target
    execute (DeleteEntry path) = deleteEntry files path
    execute (MakeDirectory path) = makeDirectory files path
    execute (EditFile editor cwd path) = editFile processes editor cwd path
    execute (RunCommand cwd command) = runCommand processes cwd command

handleInput :: Monad m => FileSystem m -> Processes m -> (Settings -> m (Either FileError ())) -> Input -> AppState -> m (AppState, Bool)
handleInput files processes save input state = do
  (updated, quit) <- runProgram files processes (planInput input state)
  let editorConfirmed = case (stMode state, stMode updated, stStatus updated) of
        (EditorPrompt _, Browse, SettingsSaved) -> True
        _ -> False
  if currentSettings updated == currentSettings state && not editorConfirmed
    then pure (updated, quit)
    else do
      result <- save (currentSettings updated)
      pure (case result of
        Right () -> updated
        Left err -> (applySettings (currentSettings state) updated)
          { stMode = stMode state, stInputCursor = stInputCursor state
          , stThemePicker = stThemePicker state, stStatus = SettingsSaveFailed err }, quit)
