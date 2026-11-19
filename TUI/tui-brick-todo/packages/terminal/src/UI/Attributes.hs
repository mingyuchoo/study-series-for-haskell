{-# LANGUAGE OverloadedStrings #-}

module UI.Attributes
  ( theMap
  ) where

import Brick (AttrMap, attrMap, attrName, fg, on)
import Brick.Widgets.List (listSelectedAttr)

import Graphics.Vty qualified as V

theMap :: AttrMap
theMap =
  attrMap
    V.defAttr
    [ (attrName "header", V.white `on` V.blue `V.withStyle` V.bold)
    , (attrName "selected", V.black `on` V.cyan)
    , (attrName "normal", V.defAttr)
    , (attrName "registered", fg V.white)
    , (attrName "in_progress", fg V.yellow)
    , (attrName "cancelled", fg V.black `V.withStyle` V.dim)
    , (attrName "completed", fg V.green)
    , (attrName "timestamp", fg V.yellow)
    , (attrName "inputHelp", fg V.cyan `V.withStyle` V.dim)
    , (attrName "focusedField", fg V.cyan `V.withStyle` V.bold)
    , (attrName "normalField", fg V.white)
    , (attrName "detailLabel", fg V.cyan `V.withStyle` V.bold)
    , (listSelectedAttr, V.black `on` V.cyan)
    , (attrName "error", fg V.red `V.withStyle` V.bold)
    ]
