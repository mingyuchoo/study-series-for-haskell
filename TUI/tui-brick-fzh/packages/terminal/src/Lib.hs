module Lib
    ( module Config
    , module Types
    , app
    , buildVtyFromTty
    ) where

import           Brick
import           Brick.Widgets.List      (listSelectedAttr)

import           Config                  (KeyBindingConfig (..),
                                          KeyBindingStyle (..),
                                          defaultKeyBindingConfig,
                                          loadKeyBindingConfig)

import           Event                   (handleEvent, loadSelectedFile)

import qualified Graphics.Vty.Attributes as V

import           Types

import           UI                      (drawUI)

import           Vty                     (buildVtyFromTty)

app :: App AppState e Name
app =
  App
    { appDraw = drawUI
    , appChooseCursor = neverShowCursor
    , appHandleEvent = handleEvent
    , appStartEvent = loadSelectedFile
    , appAttrMap = mkAttrMap
    }

mkAttrMap :: AppState -> AttrMap
mkAttrMap st =
  attrMap
    (configDefaultAttr cfg)
    [ (listSelectedAttr, configSelectedAttr cfg)
    , (attrName "syntax.keyword", fg V.brightBlue)
    , (attrName "syntax.string", fg V.yellow)
    , (attrName "syntax.comment", fg V.brightBlack)
    , (attrName "syntax.function", fg V.brightGreen)
    , (attrName "syntax.type", fg V.brightCyan)
    , (attrName "syntax.number", fg V.cyan)
    , (attrName "syntax.lineNumber", fg V.brightBlack)
    ]
  where
    cfg = stConfig st
