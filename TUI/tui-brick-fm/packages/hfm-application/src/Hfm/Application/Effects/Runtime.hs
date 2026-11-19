{-# LANGUAGE GADTs #-}

module Hfm.Application.Effects.Runtime (handleInput, runProgram) where

import           Hfm.Application.Effects.Ports
import           Hfm.Application.Error         (FileError)
import           Hfm.Application.Machine       (resume)
import           Hfm.Application.Program
import           Hfm.Application.State         (AppState)
import           Hfm.Application.Workflow      (planInput)
import           Hfm.Domain.Config             (Settings)
import           Hfm.Domain.Input              (Input)

runProgram :: forall m a. Monad m => FileSystem m -> Processes m -> (Settings -> m (Either FileError ())) -> Program a -> m a
runProgram _ _ _ (Done value) = pure value
runProgram files processes save (Await effect phase) = do
  result <- execute effect
  runProgram files processes save (resume phase result)
  where
    execute :: Request response -> m (Either FileError response)
    execute (ReadEntries hidden path)  = readEntries files hidden path
    execute (CanonicalizePath path)    = canonicalizePath files path
    execute (DirectoryExists path)     = doesDirectoryExist files path
    execute (ReadPreview path)         = readPreview files path
    execute (CopyEntry source target)  = copyEntry files source target
    execute (MoveEntry source target)  = moveEntry files source target
    execute (DeleteEntry path)         = deleteEntry files path
    execute (MakeDirectory path)       = makeDirectory files path
    execute (EditFile editor cwd path) = editFile processes editor cwd path
    execute (RunCommand cwd command)   = runCommand processes cwd command
    execute (SaveSettings settings)    = save settings

handleInput :: Monad m => FileSystem m -> Processes m -> (Settings -> m (Either FileError ())) -> Input -> AppState -> m (AppState, Lifecycle)
handleInput files processes save input state = runProgram files processes save (planInput input state)
