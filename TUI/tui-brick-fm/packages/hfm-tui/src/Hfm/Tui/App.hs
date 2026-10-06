module Hfm.Tui.App
  ( app
  , buildVtyFromTty
  ) where

import Brick
import Hfm.Tui.Theme (themeAttributes, effectiveTheme)
import Hfm.Tui.Layout (prepareLayout)
import Hfm.Application.Ports (FileSystem)
import Hfm.Tui.Event (handleEvent)
import Hfm.Tui.Name
import Hfm.Application.State
import Hfm.Tui.UI (drawUI)
import Hfm.Tui.Terminal (buildVtyFromTty)

app :: FileSystem IO -> App AppState e Name
app ports = App
  { appDraw = drawUI
  , appChooseCursor = neverShowCursor
  , appHandleEvent = handleEvent ports
  , appStartEvent = modify prepareLayout
  , appAttrMap = themeAttributes . effectiveTheme
  }
