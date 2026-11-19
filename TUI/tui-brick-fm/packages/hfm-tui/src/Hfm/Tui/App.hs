module Hfm.Tui.App
  ( app
  , buildVtyFromTty
  ) where

import           Brick

import           Hfm.Application.Effects.Ports (FileSystem, Processes)
import           Hfm.Application.Error         (FileError)
import           Hfm.Application.State
import           Hfm.Domain.Config             (Settings)
import           Hfm.Tui.Event                 (handleEvent)
import           Hfm.Tui.Layout                (prepareLayout)
import           Hfm.Tui.Name
import           Hfm.Tui.Terminal              (buildVtyFromTty)
import           Hfm.Tui.Theme                 (effectiveTheme, themeAttributes)
import           Hfm.Tui.UI                    (drawUI)

app :: FileSystem IO -> Processes IO -> (Settings -> IO (Either FileError ())) -> App AppState e Name
app files processes save = App
  { appDraw = drawUI
  , appChooseCursor = neverShowCursor
  , appHandleEvent = handleEvent files processes save
  , appStartEvent = modify prepareLayout
  , appAttrMap = themeAttributes . effectiveTheme
  }
