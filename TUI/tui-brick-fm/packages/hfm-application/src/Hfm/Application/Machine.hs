{-# LANGUAGE GADTs #-}

module Hfm.Application.Machine
  ( resume
  , refreshAll
  , changeDir
  , openView
  , finish
  , persistSettings
  ) where

import qualified Data.ByteString          as BS
import           Data.Text.Encoding       (decodeUtf8With)
import           Data.Text.Encoding.Error (lenientDecode)

import           Hfm.Application.Error    (FileError)
import           Hfm.Application.Program
import           Hfm.Application.State
import           Hfm.Application.Status
import           Hfm.Domain.PathPolicy    (destinationPath)

resume :: Phase response result -> Either FileError response -> Program result
resume ReturningResponse result = Done result
resume (Starting _) (Left err) = Done (Left err)
resume (Starting step) (Right value) = resumeStartup step value
resume (Working state (PersistingSettings previous)) (Left err) =
  continue ((applySettings (currentSettings previous) state)
    { stMode = stMode previous
    , stInputCursor = stInputCursor previous
    , stThemePicker = stThemePicker previous
    , stStatus = SettingsSaveFailed err
    })
resume (Working state _) (Left err) = continue (state { stStatus = Failed err })
resume (Working state step) (Right value) = resumeTask state step value

resumeStartup :: StartupStep response -> response -> Program (Either FileError AppState)
resumeStartup (ResolvingLeftPath context rightArg) left =
  Await (CanonicalizePath rightArg) (Starting (ResolvingRightPath context left))
resumeStartup (ResolvingRightPath context left) right =
  Await (ReadEntries False left) (Starting (LoadingLeftEntries context left right))
resumeStartup (LoadingLeftEntries context left right) leftEntries =
  Await (ReadEntries False right) (Starting (LoadingRightEntries context left leftEntries right))
resumeStartup (LoadingRightEntries (StartupContext config size) left leftEntries right) rightEntries =
  Done (Right (initialState left leftEntries right rightEntries config size))

resumeTask :: AppState -> TaskStep response -> response -> Program (AppState, Lifecycle)
resumeTask state RefreshingLeftPanel left =
  Await (ReadEntries (stShowHidden state) (panelPath (stRight state)))
    (Working state (RefreshingRightPanel left))
resumeTask state (RefreshingRightPanel left) right = continue (state
  { stLeft = refreshPanel left Nothing (stLeft state)
  , stRight = refreshPanel right Nothing (stRight state)
  })
resumeTask state (ResolvingDirectory preferred) canonical =
  Await (ReadEntries (stShowHidden state) canonical)
    (Working state (LoadingDirectory canonical preferred))
resumeTask state (LoadingDirectory canonical preferred) entries =
  let panel = refreshPanel entries preferred ((activePanel state)
        { panelPath = canonical, panelSearch = "" })
  in continue ((replaceActivePanel panel state) { stStatus = CurrentDirectory canonical })
resumeTask state (InspectingLink path) isDirectory =
  if isDirectory then changeDir path Nothing state else openView path state
resumeTask state (LoadingPreview path) bytes
  | BS.elem 0 bytes = continue (state { stStatus = BinaryPreviewUnsupported })
  | otherwise = continue (state { stMode = ViewFile path (decodeUtf8With lenientDecode bytes) 0 })
resumeTask state (InspectingDestination transfer source requested) isDirectory =
  let target = destinationPath source requested isDirectory
  in case transfer of
    CopyTransfer -> Await (CopyEntry source target) (Working state (CompletingMutation Copied))
    MoveTransfer -> Await (MoveEntry source target) (Working state (CompletingMutation Moved))
resumeTask state (CompletingMutation status) () = finish status state
resumeTask state (CompletingProcess kind) exitCode = finish (case kind of
  EditorProcess -> EditorFinished exitCode
  ShellProcess  -> CommandFinished exitCode) state
resumeTask state (PersistingSettings _) () = continue state

refreshAll :: AppState -> Program (AppState, Lifecycle)
refreshAll state = Await (ReadEntries (stShowHidden state) (panelPath (stLeft state)))
  (Working state RefreshingLeftPanel)

changeDir :: FilePath -> Maybe FilePath -> AppState -> Program (AppState, Lifecycle)
changeDir path preferred state = Await (CanonicalizePath path)
  (Working state (ResolvingDirectory preferred))

openView :: FilePath -> AppState -> Program (AppState, Lifecycle)
openView path state = Await (ReadPreview path) (Working state (LoadingPreview path))

finish :: Status -> AppState -> Program (AppState, Lifecycle)
finish status state = refreshAll (state { stMode = Browse, stStatus = status })

persistSettings :: AppState -> AppState -> Program (AppState, Lifecycle)
persistSettings previous updated = Await (SaveSettings (currentSettings updated))
  (Working updated (PersistingSettings previous))
