{-# LANGUAGE GADTs #-}

module Hfm.Application.Internal.Navigation
  ( enterSelected, goToParent, previewSelected, changeDir, openView, resumeNavigation ) where

import qualified Data.ByteString          as BS
import           Data.Text.Encoding       (decodeUtf8With)
import           Data.Text.Encoding.Error (lenientDecode)

import           Hfm.Application.Program
import           Hfm.Application.State
import           Hfm.Application.Status
import           Hfm.Domain.Entry

import           System.FilePath         (takeDirectory, takeFileName, (</>))

enterSelected :: AppState -> Program (AppState, Lifecycle)
enterSelected state = case selectedEntry state of
  Nothing -> continue state
  Just entry -> case entryKind entry of
    Parent -> goToParent state
    Directory -> changeDir (entryPath entry) Nothing state
    SymbolicLink -> let path = entryPath entry
                    in Await (DirectoryExists path) (Working state (Navigating (InspectingLink path)))
    RegularFile -> openView (entryPath entry) state
    Special -> continue (state { stStatus = SpecialFileUnsupported })
  where
    entryPath entry = panelPath (activePanel state) </> entryName entry

previewSelected :: AppState -> Program (AppState, Lifecycle)
previewSelected state = case (selectedEntry state, selectedPath state) of
  (Just entry, Just path) | entryKind entry `elem` [RegularFile, SymbolicLink] -> openView path state
  _ -> continue state

goToParent :: AppState -> Program (AppState, Lifecycle)
goToParent state = changeDir (takeDirectory current) (Just (takeFileName current)) state
  where
    current = panelPath (activePanel state)

changeDir :: FilePath -> Maybe FilePath -> AppState -> Program (AppState, Lifecycle)
changeDir path preferred state = Await (CanonicalizePath path)
  (Working state (Navigating (ResolvingDirectory preferred)))

openView :: FilePath -> AppState -> Program (AppState, Lifecycle)
openView path state = Await (ReadPreview path) (Working state (Navigating (LoadingPreview path)))

resumeNavigation :: AppState -> NavigationStep response -> response -> Program (AppState, Lifecycle)
resumeNavigation state (ResolvingDirectory preferred) canonical =
  Await (ReadEntries (stShowHidden state) canonical)
    (Working state (Navigating (LoadingDirectory canonical preferred)))
resumeNavigation state (LoadingDirectory canonical preferred) entries =
  let panel = refreshPanel entries preferred ((activePanel state)
        { panelPath = canonical, panelSearch = "" })
  in continue ((replaceActivePanel panel state) { stStatus = CurrentDirectory canonical })
resumeNavigation state (InspectingLink path) isDirectory =
  if isDirectory then changeDir path Nothing state else openView path state
resumeNavigation state (LoadingPreview path) bytes
  | BS.elem 0 bytes = continue (state { stStatus = BinaryPreviewUnsupported })
  | otherwise = continue (state { stMode = ViewFile path (decodeUtf8With lenientDecode bytes) 0 })
