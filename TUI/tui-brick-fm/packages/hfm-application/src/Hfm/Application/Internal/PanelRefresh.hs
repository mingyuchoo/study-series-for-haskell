{-# LANGUAGE GADTs #-}

module Hfm.Application.Internal.PanelRefresh
  ( refreshAll, toggleHidden, finish, resumeRefresh ) where

import           Hfm.Application.Program
import           Hfm.Application.State
import           Hfm.Application.Status (Status)

refreshAll :: AppState -> Program (AppState, Lifecycle)
refreshAll state = refreshWith (stShowHidden state) state

toggleHidden :: AppState -> Program (AppState, Lifecycle)
toggleHidden state = refreshWith (not (stShowHidden state)) state

refreshWith :: Bool -> AppState -> Program (AppState, Lifecycle)
refreshWith showHidden state = Await (ReadEntries showHidden (panelPath (stLeft state)))
  (Working state (Refreshing showHidden RefreshingLeftPanel))

resumeRefresh :: AppState -> Bool -> RefreshStep response -> response -> Program (AppState, Lifecycle)
resumeRefresh state showHidden RefreshingLeftPanel left =
  Await (ReadEntries showHidden (panelPath (stRight state)))
    (Working state (Refreshing showHidden (RefreshingRightPanel left)))
resumeRefresh state showHidden (RefreshingRightPanel left) right = continue (state
  { stLeft = refreshPanel left Nothing (stLeft state)
  , stRight = refreshPanel right Nothing (stRight state)
  , stShowHidden = showHidden
  })

finish :: Status -> AppState -> Program (AppState, Lifecycle)
finish status state = refreshAll (state { stMode = Browse, stStatus = status })
