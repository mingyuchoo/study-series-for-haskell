module Hfm.Application.Internal.Files
  ( refreshAll, changeDir, enterSelected, openView, openEditor, runOperation, deleteSelected, finish ) where

import Control.Monad.Except (ExceptT (..), runExceptT)
import Control.Monad.State.Strict (get, modify)
import qualified Data.ByteString as BS
import qualified Data.Text as T
import Data.Text.Encoding (decodeUtf8With)
import Data.Text.Encoding.Error (lenientDecode)
import Hfm.Application.Internal.Action
import Hfm.Application.Program
import Hfm.Application.State
import Hfm.Application.Status
import Hfm.Domain.Entry
import Hfm.Domain.PathPolicy
import System.FilePath (takeDirectory, takeFileName, (</>))

refreshAll :: Action ()
refreshAll = do
  st <- get
  attempt (runExceptT $ do
    left <- ExceptT (request (ReadEntries (stShowHidden st) (panelPath (stLeft st))))
    right <- ExceptT (request (ReadEntries (stShowHidden st) (panelPath (stRight st))))
    pure (left, right)) $ \(left, right) ->
      modify (\s -> s { stLeft = refreshPanel left Nothing (stLeft s)
                      , stRight = refreshPanel right Nothing (stRight s) })

changeDir :: FilePath -> Maybe FilePath -> Action ()
changeDir path preferred = do
  st <- get
  attempt (runExceptT $ do
    canonical <- ExceptT (request (CanonicalizePath path))
    entries <- ExceptT (request (ReadEntries (stShowHidden st) canonical))
    pure (canonical, entries)) $ \(canonical, entries) ->
      modify (\s ->
        let old = activePanel s
            panel = refreshPanel entries preferred (old { panelPath = canonical, panelSearch = "" })
        in (replaceActivePanel panel s) { stStatus = CurrentDirectory canonical })

enterSelected :: Action ()
enterSelected = do
  st <- get
  case selectedEntry st of
    Nothing -> pure ()
    Just entry -> case entryKind entry of
      Parent -> let current = panelPath (activePanel st)
                in changeDir (takeDirectory current) (Just (takeFileName current))
      Directory -> changeDir (panelPath (activePanel st) </> entryName entry) Nothing
      SymbolicLink -> do
        let path = panelPath (activePanel st) </> entryName entry
        attempt (request (DirectoryExists path)) $ \isDir -> if isDir then changeDir path Nothing else openView path
      RegularFile -> openView (panelPath (activePanel st) </> entryName entry)
      Special -> modify (\s -> s { stStatus = SpecialFileUnsupported })

openView :: FilePath -> Action ()
openView path = attempt (request (ReadPreview path)) $ \bytes ->
  if BS.elem 0 bytes
    then modify (\s -> s { stStatus = BinaryPreviewUnsupported })
    else modify (\s -> s { stMode = ViewFile path (decodeUtf8With lenientDecode bytes) 0 })

openEditor :: Action ()
openEditor = do
  st <- get
  case (selectedEntry st, selectedPath st) of
    (Just entry, Just path) | entryKind entry `elem` [RegularFile, SymbolicLink] ->
      attempt (request (EditFile (panelPath (activePanel st)) path)) (finish . EditorFinished)
    _ -> pure ()

runOperation :: Operation -> T.Text -> Action ()
runOperation Command raw = do
  st <- get
  if T.null (T.strip raw) || T.any (== '\0') raw
    then modify (\s -> s { stStatus = InvalidCommand })
    else attempt (request (RunCommand (panelPath (activePanel st)) raw)) (finish . CommandFinished)
runOperation op raw = do
  st <- get
  let input = T.unpack (T.strip raw)
      cwd = panelPath (activePanel st)
  if not (validDestination input) || (op `elem` [Mkdir, Rename] && not (validDirectoryName input))
    then modify (\s -> s { stStatus = InvalidDestination })
    else case op of
      Mkdir -> attempt (request (MakeDirectory (requestedPath cwd input))) $ \_ -> finish DirectoryCreated
      Copy -> runTransfer CopyEntry Copied cwd input st
      Move -> runTransfer MoveEntry Moved cwd input st
      Rename -> case selectedPath st of
        Just source -> attempt (request (MoveEntry source (cwd </> input))) $ \_ -> finish Moved
        Nothing -> pure ()

runTransfer :: (FilePath -> FilePath -> FileRequest ()) -> Status -> FilePath -> FilePath -> AppState -> Action ()
runTransfer operation message cwd input st = case selectedPath st of
  Nothing -> pure ()
  Just source -> attempt (runExceptT $ do
    let requested = requestedPath cwd input
    isDir <- ExceptT (request (DirectoryExists requested))
    let target = destinationPath source requested isDir
    ExceptT (request (operation source target))) $ \_ -> finish message

finish :: Status -> Action ()
finish message = do
  modify (\s -> s { stMode = Browse, stStatus = message })
  refreshAll

deleteSelected :: Action ()
deleteSelected = do
  st <- get
  case selectedPath st of
    Nothing -> modify (\s -> s { stMode = Browse })
    Just path -> attempt (request (DeleteEntry path)) $ \_ -> finish Deleted
