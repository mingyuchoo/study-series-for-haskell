{-# LANGUAGE OverloadedStrings #-}

-- | Application entry point and integration
--
-- This module integrates all components and defines the Brick application.
-- Re-exports are limited to types and functions needed by Main.
module Lib
    ( AppState (..)
    , FocusedField (..)
    , Mode (..)
    , Name (..)
    , Todo (..)
    , app
    , fromTodoRow
    ) where

import           Brick         (App (..), showCursorNamed)

import           Lens.Micro    ((^.))

import           UI.Attributes (theMap)
import           UI.Draw       (drawUI)
import           UI.Events     (handleEvent)
import           UI.Types

-- | 애플리케이션 정의 (Pure)
app :: App AppState e Name
app = App
    { appDraw = drawUI
    , appChooseCursor = \s locs -> case s ^. mode of
        InputMode -> case s ^. focusedField of
            FocusAction         -> showCursorNamed ActionField locs
            FocusSubject        -> showCursorNamed SubjectField locs
            FocusIndirectObject -> showCursorNamed IndirectObjectField locs
            FocusDirectObject   -> showCursorNamed DirectObjectField locs
        EditMode _ -> case s ^. focusedField of
            FocusAction         -> showCursorNamed ActionField locs
            FocusSubject        -> showCursorNamed SubjectField locs
            FocusIndirectObject -> showCursorNamed IndirectObjectField locs
            FocusDirectObject   -> showCursorNamed DirectObjectField locs
        ViewMode -> Nothing
    , appHandleEvent = handleEvent
    , appStartEvent = return ()
    , appAttrMap = const theMap
    }
