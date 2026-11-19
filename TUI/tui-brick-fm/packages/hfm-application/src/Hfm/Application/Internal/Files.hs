module Hfm.Application.Internal.Files
  ( enterSelected, runFileOperation, deleteSelected ) where

import qualified Data.Text               as T

import           Hfm.Application.Machine (changeDir, openView)
import           Hfm.Application.Program
import           Hfm.Application.State
import           Hfm.Application.Status
import           Hfm.Domain.Entry
import           Hfm.Domain.PathPolicy

import           System.FilePath         (takeDirectory, takeFileName, (</>))

enterSelected :: AppState -> Program (AppState, Lifecycle)
enterSelected state = case selectedEntry state of
  Nothing -> continue state
  Just entry -> case entryKind entry of
    Parent -> let current = panelPath (activePanel state)
              in changeDir (takeDirectory current) (Just (takeFileName current)) state
    Directory -> changeDir (entryPath entry) Nothing state
    SymbolicLink -> let path = entryPath entry
                    in Await (DirectoryExists path) (Working state (InspectingLink path))
    RegularFile -> openView (entryPath entry) state
    Special -> continue (state { stStatus = SpecialFileUnsupported })
  where
    entryPath entry = panelPath (activePanel state) </> entryName entry

runFileOperation :: Operation -> T.Text -> AppState -> Program (AppState, Lifecycle)
runFileOperation Command _ state = continue state
runFileOperation operation raw state
  | not (validDestination input) || (operation `elem` [Mkdir, Rename] && not (validDirectoryName input)) =
      continue (state { stStatus = InvalidDestination })
  | otherwise = case operation of
      Mkdir -> Await (MakeDirectory (requestedPath cwd input)) (Working state (CompletingMutation DirectoryCreated))
      Copy -> transfer CopyTransfer
      Move -> transfer MoveTransfer
      Rename -> case selectedPath state of
        Just source -> Await (MoveEntry source (cwd </> input)) (Working state (CompletingMutation Moved))
        Nothing -> continue state
  where
    input = T.unpack (T.strip raw)
    cwd = panelPath (activePanel state)
    transfer kind = case selectedPath state of
      Nothing -> continue state
      Just source -> let target = requestedPath cwd input
                     in Await (DirectoryExists target) (Working state (InspectingDestination kind source target))

deleteSelected :: AppState -> Program (AppState, Lifecycle)
deleteSelected state = case selectedPath state of
  Nothing -> continue (state { stMode = Browse })
  Just path -> Await (DeleteEntry path) (Working state (CompletingMutation Deleted))
