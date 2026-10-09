{-# LANGUAGE GADTs #-}

module Hfm.Application.UseCases (handleInput, runProgram) where

import Hfm.Application.Ports
import Hfm.Application.Program
import Hfm.Application.State (AppState)
import Hfm.Application.Workflow (planInput)
import Hfm.Domain.Input (Input)

-- Effectful shell: the only application module that executes supplied ports.
runProgram :: forall m a. Monad m => FileSystem m -> Program a -> m a
runProgram _ (Done value) = pure value
runProgram ports (Await effect resume) = do
  result <- execute effect
  runProgram ports (resume result)
  where
    execute :: FileRequest b -> m (Either FileError b)
    execute (ReadEntries hidden path) = readEntries ports hidden path
    execute (CanonicalizePath path) = canonicalizePath ports path
    execute (DirectoryExists path) = doesDirectoryExist ports path
    execute (ReadPreview path) = readPreview ports path
    execute (CopyEntry source target) = copyEntry ports source target
    execute (MoveEntry source target) = moveEntry ports source target
    execute (DeleteEntry path) = deleteEntry ports path
    execute (MakeDirectory path) = makeDirectory ports path
    execute (EditFile cwd path) = editFile ports cwd path
    execute (RunCommand cwd command) = runCommand ports cwd command

handleInput :: Monad m => FileSystem m -> Input -> AppState -> m (AppState, Bool)
handleInput ports input = runProgram ports . planInput input
