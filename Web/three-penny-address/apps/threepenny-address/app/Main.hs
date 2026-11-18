module Main (main) where

import AddressBook.JsonRepository (openJsonRepository)
import Data.ByteString.Char8 qualified as ByteString
import Graphics.UI.Threepenny.Core (Config (..), defaultConfig, startGUI)
import GUI.Main (setupGUI)
import System.Environment (lookupEnv)
import Data.Maybe (fromMaybe)
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  contactsPath <- fromMaybe "contacts.json" <$> lookupEnv "ADDRESS_BOOK_CONTACTS_FILE"
  listenAddress <- fmap ByteString.pack <$> lookupEnv "ADDRESS_BOOK_BIND_ADDRESS"
  repository <- openJsonRepository contactsPath
  putStrLn "Server starting on http://localhost:8023"
  startGUI
    defaultConfig
      { jsPort = Just 8023
      , jsAddr = listenAddress
      , jsStatic = Just "static"
      , jsCustomHTML = Just "index.html"
      }
    (setupGUI repository)
