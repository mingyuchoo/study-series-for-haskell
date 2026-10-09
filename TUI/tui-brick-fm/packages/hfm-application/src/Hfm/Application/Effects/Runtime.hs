{-# LANGUAGE GADTs #-}

module Hfm.Application.Effects.Runtime (handleInput, runProgram) where

import Hfm.Application.Effects.Ports
import Hfm.Application.Error (FileError)
import Hfm.Application.Program
import Hfm.Application.State (AppState)
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
    execute (EditFile cwd path) = editFile processes cwd path
    execute (RunCommand cwd command) = runCommand processes cwd command

handleInput :: Monad m => FileSystem m -> Processes m -> Input -> AppState -> m (AppState, Bool)
handleInput files processes input = runProgram files processes . planInput input
