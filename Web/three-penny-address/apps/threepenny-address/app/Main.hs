module Main (main) where

import AddressBook.Http (addressBookApplication)
import AddressBook.JsonRepository (openJsonRepository)
import Data.Maybe (fromMaybe)
import Data.String (fromString)
import Network.Wai.Handler.Warp (defaultSettings, runSettings, setHost, setPort)
import System.Environment (lookupEnv)
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  contactsPath <- fromMaybe "contacts.json" <$> lookupEnv "ADDRESS_BOOK_CONTACTS_FILE"
  listenAddress <- fromMaybe "127.0.0.1" <$> lookupEnv "ADDRESS_BOOK_BIND_ADDRESS"
  staticDirectory <- fromMaybe "static" <$> lookupEnv "ADDRESS_BOOK_STATIC_DIRECTORY"
  repository <- openJsonRepository contactsPath
  putStrLn "Server starting on http://localhost:8023"
  runSettings (setHost (fromString listenAddress) $ setPort 8023 defaultSettings) $
    addressBookApplication staticDirectory repository
