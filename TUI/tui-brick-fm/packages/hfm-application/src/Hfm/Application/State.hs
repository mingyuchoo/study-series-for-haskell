{-# LANGUAGE OverloadedStrings #-}

module Hfm.Application.State
  ( AppConfig (..)
  , AppState (..)
  , Theme (..)
  , toggleThemePicker
  , Language (..)
  , toggleLanguage
  , Side (..)
  , Panel (..)
  , Mode (..)
  , Operation (..)
  , defaultConfig
  , configWithKeyBinding
  , initialState
  , activePanel
  , replaceActivePanel
  , selectedEntry
  , selectedPath
  , visibleEntries
  , refreshPanel
  , moveSelection
  , viewerContentHeight
  , clampViewerOffset
  , maxPreviewLines
  ) where

import Hfm.Application.Status (Status (Ready))
import System.FilePath ((</>))
import Hfm.Domain.Theme
import Hfm.Domain.Selection
import Hfm.Domain.Config (KeyBindingConfig (..), KeyBindingStyle (..))
import Control.Applicative ((<|>))
import Data.List (findIndex)
import qualified Data.Text as T
import Hfm.Domain.Entry (Entry (..), EntryKind (..))
import Hfm.Domain.Language (Language (..))

data Side = LeftSide | RightSide deriving (Eq, Show)
data Operation = Copy | Move | Rename | Mkdir | Command deriving (Eq, Show)
data Mode = Browse | Search | Prompt Operation T.Text | ConfirmDelete | ViewFile FilePath T.Text Int deriving (Eq, Show)

data Panel = Panel
  { panelPath :: FilePath
  , panelEntries :: Selection Entry
  , panelAll :: [Entry]
  , panelSearch :: T.Text
  }

data AppConfig = AppConfig { configKeyBinding :: KeyBindingStyle }

data AppState = AppState
  { stLeft :: Panel
  , stRight :: Panel
  , stActive :: Side
  , stTheme :: Theme
  , stThemePicker :: Maybe (Selection Theme)
  , stLanguage :: Language
  , stMode :: Mode
  , stInputCursor :: Int
  , stPendingCtrlX :: Bool
  , stShowHidden :: Bool
  , stStatus :: Status
  , stTerminalSize :: (Int, Int)
  , stViewerFooterRows :: Int
  , stConfig :: AppConfig
  }

defaultConfig :: AppConfig
defaultConfig = AppConfig Emacs

configWithKeyBinding :: KeyBindingConfig -> AppConfig
configWithKeyBinding cfg = AppConfig (bindingStyle cfg)

initialState :: FilePath -> [Entry] -> FilePath -> [Entry] -> AppConfig -> (Int, Int) -> AppState
initialState left leftEntries right rightEntries cfg size = AppState
  { stLeft = Panel left (selection leftEntries) leftEntries ""
  , stRight = Panel right (selection rightEntries) rightEntries ""
  , stActive = LeftSide
  , stTheme = Dark
  , stThemePicker = Nothing
  , stLanguage = Korean
  , stMode = Browse
  , stInputCursor = 0
  , stPendingCtrlX = False
  , stShowHidden = False
  , stStatus = Ready
  , stTerminalSize = size
  , stViewerFooterRows = 1
  , stConfig = cfg
  }

-- Layout-dependent clamping is performed by the presentation adapter.
toggleLanguage :: AppState -> AppState
toggleLanguage st = st { stLanguage = case stLanguage st of
                          Korean -> English
                          English -> Korean }

-- The picker is independent of the current file operation or viewer mode.
-- Canceling a preview never changes the committed theme.
toggleThemePicker :: AppState -> AppState
toggleThemePicker st = st { stThemePicker = case stThemePicker st of
  Just _ -> Nothing
  Nothing -> Just (selectAt (fromEnum (stTheme st)) (selection themes)) }

activePanel :: AppState -> Panel
activePanel st = if stActive st == LeftSide then stLeft st else stRight st

replaceActivePanel :: Panel -> AppState -> AppState
replaceActivePanel panel st = case stActive st of
  LeftSide -> st { stLeft = panel }
  RightSide -> st { stRight = panel }

selectedEntry :: AppState -> Maybe Entry
selectedEntry = fmap snd . selectedElement . panelEntries . activePanel

selectedPath :: AppState -> Maybe FilePath
selectedPath st = do
  entry <- selectedEntry st
  if entryKind entry == Parent then Nothing
    else Just (panelPath (activePanel st) </> entryName entry)

visibleEntries :: T.Text -> [Entry] -> [Entry]
visibleEntries query = filter (\e -> entryKind e == Parent || T.toCaseFold query `T.isInfixOf` T.toCaseFold (T.pack (entryName e)))

refreshPanel :: [Entry] -> Maybe FilePath -> Panel -> Panel
refreshPanel entries preferred panel =
  let oldName = entryName . snd <$> selectedElement (panelEntries panel)
      names = visibleEntries (panelSearch panel) entries
      wanted = preferred <|> oldName
      index = wanted >>= \name -> findIndex ((== name) . entryName) names
      newList = selection names
  in panel { panelEntries = maybe newList (`selectAt` newList) index, panelAll = entries }

moveSelection :: Bool -> AppState -> AppState
moveSelection down st =
  let panel = activePanel st
      entries = panelEntries panel
      moved = if down then selectStep 1 entries else selectStep (-1) entries
  in replaceActivePanel (panel { panelEntries = moved }) st

viewerContentHeight :: AppState -> Int
viewerContentHeight st = max 0 (snd (stTerminalSize st) - 3 - stViewerFooterRows st)

clampViewerOffset :: AppState -> T.Text -> Int -> Int
clampViewerOffset st content offset =
  max 0 (min (max 0 (length (T.lines content) - max 1 (viewerContentHeight st))) offset)

maxPreviewLines :: Int
maxPreviewLines = 100
