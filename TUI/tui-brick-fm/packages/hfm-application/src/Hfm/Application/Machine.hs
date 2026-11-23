{-# LANGUAGE GADTs #-}

module Hfm.Application.Machine
  ( resume
  , refreshAll
  , changeDir
  , openView
  , finish
  , persistSettings
  ) where

import           Hfm.Application.Error                 (FileError)
import           Hfm.Application.Internal.Files        (resumeFiles)
import           Hfm.Application.Internal.Navigation   (changeDir, openView,
                                                        resumeNavigation)
import           Hfm.Application.Internal.PanelRefresh (finish, refreshAll,
                                                        resumeRefresh)
import           Hfm.Application.Internal.Process      (resumeProcess)
import           Hfm.Application.Internal.Settings     (persistSettings,
                                                        resumeSettings)
import           Hfm.Application.Program
import           Hfm.Application.Startup               (resumeStartup)
import           Hfm.Application.State
import           Hfm.Application.Status                (Status (Failed))

resume :: Phase response result -> Either FileError response -> Program result
resume ReturningResponse result = Done result
resume (Starting step) result = resumeStartup step result
resume (Working updated (PersistingSettings previous)) result = resumeSettings previous updated result
resume (Working state _) (Left err) = continue (state { stStatus = Failed err })
resume (Working state (Navigating step)) (Right value) = resumeNavigation state step value
resume (Working state (ChangingFiles step)) (Right value) = resumeFiles state step value
resume (Working state (Refreshing showHidden step)) (Right value) = resumeRefresh state showHidden step value
resume (Working state (CompletingProcess kind)) (Right exitCode) = resumeProcess state kind exitCode
