{-# LANGUAGE GADTs #-}

module Hfm.Application.Internal.Files
  ( startPrompt, runFileOperation, deleteSelected, resumeFiles ) where

import qualified Data.Text               as T

import           Hfm.Application.Internal.PanelRefresh (finish)
import           Hfm.Application.Program
import           Hfm.Application.State
import           Hfm.Application.Status
import           Hfm.Domain.Entry
import           Hfm.Domain.PathPolicy

import           System.FilePath         ((</>))

startPrompt :: Operation -> AppState -> AppState
startPrompt operation state = case selectedEntry state of
  Just entry | entryKind entry `notElem` [Parent, Special] ->
    let other = case stActive state of
          LeftSide  -> stRight state
          RightSide -> stLeft state
        value = T.pack (if operation == Rename then entryName entry else panelPath other)
    in state { stMode = Prompt operation value, stInputCursor = T.length value }
  _ -> state

runFileOperation :: Operation -> T.Text -> AppState -> Program (AppState, Lifecycle)
runFileOperation Command _ state = continue state
runFileOperation operation raw state
  | not (validDestination input) || (operation `elem` [Mkdir, Rename] && not (validDirectoryName input)) =
      continue (state { stStatus = InvalidDestination })
  | otherwise = case operation of
      Mkdir -> mutate state DirectoryCreated (MakeDirectory (requestedPath cwd input))
      Copy -> transfer CopyTransfer
      Move -> transfer MoveTransfer
      Rename -> case selectedPath state of
        Just source -> mutate state Moved (MoveEntry source (cwd </> input))
        Nothing -> continue state
  where
    input = T.unpack (T.strip raw)
    cwd = panelPath (activePanel state)
    transfer kind = case selectedPath state of
      Nothing -> continue state
      Just source ->
        let target = requestedPath cwd input
            context = TransferContext kind (SourceEntry source) (RequestedDestination target)
        in Await (DirectoryExists target) (Working state (ChangingFiles (InspectingDestination context)))

deleteSelected :: AppState -> Program (AppState, Lifecycle)
deleteSelected state = case selectedPath state of
  Nothing -> continue (state { stMode = Browse })
  Just path -> mutate state Deleted (DeleteEntry path)

mutate :: AppState -> Status -> Request () -> Program (AppState, Lifecycle)
mutate state status effect = Await effect (Working state (ChangingFiles (CompletingMutation status)))

resumeFiles :: AppState -> FileStep response -> response -> Program (AppState, Lifecycle)
resumeFiles state (InspectingDestination (TransferContext kind (SourceEntry source) (RequestedDestination requested))) isDirectory =
  let target = destinationPath source requested isDirectory
  in case kind of
    CopyTransfer -> mutate state Copied (CopyEntry source target)
    MoveTransfer -> mutate state Moved (MoveEntry source target)
resumeFiles state (CompletingMutation status) () = finish status state
