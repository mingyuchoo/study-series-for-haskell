module Hfm.Tui.App
  ( app
  , buildVtyFromTty
  ) where

import Brick
import Hfm.Tui.Layout (prepareLayout)
import Brick.Widgets.List (listSelectedAttr, listSelectedFocusedAttr)
import Hfm.Application.Ports (FileSystem)
import Hfm.Tui.Event (handleEvent)
import qualified Graphics.Vty as V
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
  , appAttrMap = const $ attrMap V.defAttr
      [ (listSelectedAttr, V.black `on` V.cyan)
      , (listSelectedFocusedAttr, V.black `on` V.yellow)
      , (attrName "header", V.white `on` V.blue)
      , (attrName "input", V.yellow `on` V.black)
      , (attrName "status", V.black `on` V.white)
      , (attrName "keys", V.white `on` V.blue)
      , (attrName "active", V.cyan `on` V.black)
      , (attrName "inactive", V.white `on` V.black)
      , (attrName "selected", V.black `on` V.yellow)
      , (attrName "selectedInactive", V.black `on` V.white)
      ]
  }
