module GUI.AppState
    ( AppState (..)
    , emptyAppState
    ) where

import           Data.Text               (Text)
import qualified Data.Text               as T

import           AddressBook.Domain.State (AddressBookState,
                                          emptyAddressBookState)

data AppState = AppState { appAddressBook :: AddressBookState
                         , searchTerm     :: Text
                         }
     deriving (Eq, Show)

emptyAppState :: AppState
emptyAppState =
  AppState
    { appAddressBook = emptyAddressBookState
    , searchTerm = T.empty
    }
