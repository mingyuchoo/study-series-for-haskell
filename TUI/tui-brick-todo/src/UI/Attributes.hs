{-# LANGUAGE OverloadedStrings #-}

-- | UI attributes and styles (Pure)
--
-- This module defines visual attributes for the terminal UI.
-- All definitions are pure data.
--
-- Pure components:
--   - theMap: Attribute map for colors and styles
--
-- Effects: NONE - Pure configuration data
module UI.Attributes
    ( theMap
    ) where

import           Brick              (AttrMap, attrMap, attrName, fg, on)
import           Brick.Widgets.List (listSelectedAttr)

import qualified Graphics.Vty       as V

-- | 속성 맵 (Pure)
theMap :: AttrMap
theMap =
  attrMap
    V.defAttr
    [ (attrName "header", V.white `on` V.blue `V.withStyle` V.bold),
      (attrName "selected", V.black `on` V.cyan),
      (attrName "normal", V.defAttr),
      (attrName "registered", fg V.white),  -- 흰색
      (attrName "in_progress", fg V.yellow),      -- 주황색 (터미널에서 yellow가 주황색에 가까움)
      (attrName "cancelled", fg V.black `V.withStyle` V.dim),  -- 어두운 회색
      (attrName "completed", fg V.green),         -- 녹색
      (attrName "timestamp", fg V.yellow),
      (attrName "inputHelp", fg V.cyan `V.withStyle` V.dim),
      (attrName "focusedField", fg V.cyan `V.withStyle` V.bold),
      (attrName "normalField", fg V.white),
      (attrName "detailLabel", fg V.cyan `V.withStyle` V.bold),
      (listSelectedAttr, V.black `on` V.cyan),
      (attrName "error", fg V.red `V.withStyle` V.bold)
    ]
