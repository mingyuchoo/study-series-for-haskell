module Main (main) where

import Brick (defaultMain)
import Control.Exception (bracket)
import Control.Monad (void)
import DB qualified
import Database.SQLite.Simple (close, open)
import Infrastructure.Configuration (loadKeyBindingsWithMessages, loadLanguage)
import Infrastructure.Messages (loadMessages)
import Infrastructure.Repository (sqliteRepository)
import Lib (app)
import System.Directory (createDirectoryIfMissing, getHomeDirectory)
import System.FilePath ((</>))
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)
import UI.Types (initialState)

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  home <- getHomeDirectory
  let configDirectory = home </> ".config" </> "tto"
  createDirectoryIfMissing True configDirectory
  language <- loadLanguage configDirectory
  messages <- loadMessages configDirectory language
  bindings <- loadKeyBindingsWithMessages (configDirectory </> "keybindings.yaml") messages
  bracket (open $ configDirectory </> "todos.db") close $ \connection -> do
    DB.initDBWithMessages connection messages
    void $ defaultMain (app $ sqliteRepository connection) $ initialState bindings messages
