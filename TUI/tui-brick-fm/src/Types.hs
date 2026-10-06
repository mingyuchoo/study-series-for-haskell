{-# LANGUAGE OverloadedStrings #-}

module Types
  ( AppConfig (..)
  , AppState (..)
  , Side (..)
  , Name (..)
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
  , maxPreviewLines
  ) where

import Brick.Widgets.List (List, list, listMoveDown, listMoveUp, listSelectedElement, listMoveTo)
import Config (KeyBindingConfig (..), KeyBindingStyle (..))
import Control.Applicative ((<|>))
import Data.List (findIndex)
import qualified Data.Text as T
import qualified Data.Vector as Vec
import FileManager (Entry (..), EntryKind (..))

data Name = LeftList | RightList deriving (Eq, Ord, Show)
data Side = LeftSide | RightSide deriving (Eq, Show)
data Operation = Copy | Move | Mkdir deriving (Eq, Show)
data Mode = Browse | Search | Prompt Operation T.Text | ConfirmDelete | ViewFile FilePath T.Text Int deriving (Eq, Show)

data Panel = Panel
  { panelName :: Name
  , panelPath :: FilePath
  , panelEntries :: List Name Entry
  , panelAll :: [Entry]
  , panelSearch :: T.Text
  }

data AppConfig = AppConfig { configKeyBinding :: KeyBindingStyle }

data AppState = AppState
  { stLeft :: Panel
  , stRight :: Panel
  , stActive :: Side
  , stMode :: Mode
  , stInputCursor :: Int
  , stShowHidden :: Bool
  , stStatus :: T.Text
  , stTerminalSize :: (Int, Int)
  , stConfig :: AppConfig
  }

defaultConfig :: AppConfig
defaultConfig = AppConfig Emacs

configWithKeyBinding :: KeyBindingConfig -> AppConfig
configWithKeyBinding cfg = AppConfig (bindingStyle cfg)

initialState :: FilePath -> [Entry] -> FilePath -> [Entry] -> AppConfig -> (Int, Int) -> AppState
initialState left leftEntries right rightEntries cfg size = AppState
  { stLeft = Panel LeftList left (list LeftList (Vec.fromList leftEntries) 1) leftEntries ""
  , stRight = Panel RightList right (list RightList (Vec.fromList rightEntries) 1) rightEntries ""
  , stActive = LeftSide
  , stMode = Browse
  , stInputCursor = 0
  , stShowHidden = False
  , stStatus = "준비"
  , stTerminalSize = size
  , stConfig = cfg
  }

activePanel :: AppState -> Panel
activePanel st = if stActive st == LeftSide then stLeft st else stRight st

replaceActivePanel :: Panel -> AppState -> AppState
replaceActivePanel panel st = case stActive st of
  LeftSide -> st { stLeft = panel }
  RightSide -> st { stRight = panel }

selectedEntry :: AppState -> Maybe Entry
selectedEntry = fmap snd . listSelectedElement . panelEntries . activePanel

selectedPath :: AppState -> Maybe FilePath
selectedPath st = do
  entry <- selectedEntry st
  if entryKind entry == Parent then Nothing
    else Just (panelPath (activePanel st) ++ "/" ++ entryName entry)

visibleEntries :: T.Text -> [Entry] -> [Entry]
visibleEntries query = filter (\e -> entryKind e == Parent || T.toCaseFold query `T.isInfixOf` T.toCaseFold (T.pack (entryName e)))

refreshPanel :: [Entry] -> Maybe FilePath -> Panel -> Panel
refreshPanel entries preferred panel =
  let oldName = entryName . snd <$> listSelectedElement (panelEntries panel)
      names = visibleEntries (panelSearch panel) entries
      wanted = preferred <|> oldName
      index = wanted >>= \name -> findIndex ((== name) . entryName) names
      newList = list (panelName panel) (Vec.fromList names) 1
  in panel { panelEntries = maybe newList (`listMoveTo` newList) index, panelAll = entries }

moveSelection :: Bool -> AppState -> AppState
moveSelection down st =
  let panel = activePanel st
      entries = panelEntries panel
      moved = if down then listMoveDown entries else listMoveUp entries
  in replaceActivePanel (panel { panelEntries = moved }) st

maxPreviewLines :: Int
maxPreviewLines = 100
