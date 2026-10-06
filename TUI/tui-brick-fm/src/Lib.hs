module Lib
  ( module Config
  , module Types
  , app
  , buildVtyFromTty
  ) where

import Brick
import Brick.Widgets.List (listSelectedAttr, listSelectedFocusedAttr)
import Config
import Event (handleEvent)
import qualified Graphics.Vty as V
import Types
import UI (drawUI)
import Vty (buildVtyFromTty)

app :: App AppState e Name
app = App
  { appDraw = drawUI
  , appChooseCursor = neverShowCursor
  , appHandleEvent = handleEvent
  , appStartEvent = pure ()
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
