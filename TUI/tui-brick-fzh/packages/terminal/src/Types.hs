module Types
    ( AppConfig (..)
    , AppState
    , Name (..)
    , configWithKeyBinding
    , contentHeight
    , defaultConfig
    , initialState
    , isTerminalSizeSufficient
    , maxPreviewLines
    , minTerminalHeight
    , minTerminalWidth
    , previewWidth
    , resultListWidth
    , stConfig
    , stFilteredList
    , stItems
    , stSearchQuery
    , stSession
    , stTerminalSize
    , transitionApp
    ) where

import           Brick              (on)
import           Brick.Widgets.List (List, list, listMoveTo)

import           Config             (KeyBindingConfig (..),
                                     KeyBindingStyle (..))

import qualified Data.Text          as T
import qualified Data.Vector        as Vec

import qualified Fzh.Domain.Search  as Search
import           Fzh.Domain.Session

import qualified Graphics.Vty       as V

data Name = ItemList
     deriving (Eq, Ord, Show)

data AppConfig = AppConfig { configMaxWidth     :: !Int
                           , configDefaultAttr  :: !V.Attr
                           , configSelectedAttr :: !V.Attr
                           , configKeyBinding   :: !KeyBindingStyle
                           }

data AppState = AppState { stSession      :: !Session
                         , stConfig       :: !AppConfig
                         , stFilteredList :: !(List Name T.Text)
                         }

defaultConfig :: AppConfig
defaultConfig = AppConfig 80 V.defAttr (V.white `on` V.blue) Emacs

configWithKeyBinding :: KeyBindingConfig -> AppConfig
configWithKeyBinding config = defaultConfig {configKeyBinding = bindingStyle config}

initialState :: [T.Text] -> AppConfig -> (Int, Int) -> AppState
initialState items config size =
  AppState
    (newSession (map T.unpack items) size)
    config
    (list ItemList (Vec.fromList items) 1)

transitionApp :: SessionEvent -> AppState -> (AppState, [SessionCommand])
transitionApp event state =
  let (session, commands) = transitionSession event (stSession state)
      previous = browserSearch (sessionBrowser (stSession state))
      search = browserSearch (sessionBrowser session)
      widget
        | Search.query previous == Search.query search = stFilteredList state
        | otherwise = list ItemList (Vec.fromList (map T.pack (Search.results search))) 1
      selected = maybe widget (`listMoveTo` widget) (Search.selectedIndex search)
   in (state {stSession = session, stFilteredList = selected}, commands)

stItems :: AppState -> Vec.Vector T.Text
stItems =
  Vec.fromList . map T.pack . Search.allItems . browserSearch . sessionBrowser . stSession

stSearchQuery :: AppState -> T.Text
stSearchQuery = T.pack . Search.query . browserSearch . sessionBrowser . stSession

stTerminalSize :: AppState -> (Int, Int)
stTerminalSize = browserSize . sessionBrowser . stSession

minTerminalWidth :: Int
minTerminalWidth = 80

minTerminalHeight :: Int
minTerminalHeight = 24

maxPreviewLines :: Int
maxPreviewLines = 100

isTerminalSizeSufficient :: (Int, Int) -> Bool
isTerminalSizeSufficient (width, height) = width >= minTerminalWidth && height >= minTerminalHeight

resultListWidth :: Int -> Int
resultListWidth width = width * 2 `div` 5

previewWidth :: Int -> Int
previewWidth width = width - resultListWidth width

contentHeight :: Int -> Int
contentHeight height = height - 8
