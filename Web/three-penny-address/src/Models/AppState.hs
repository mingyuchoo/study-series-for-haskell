module Models.AppState
    ( AppState (..)
    , emptyAppState
    ) where

import           Data.Aeson              (FromJSON, ToJSON)
import           Data.Text               (Text)
import qualified Data.Text               as T

import           GHC.Generics            (Generic)

import           Models.AddressBookState (AddressBookState,
                                          emptyAddressBookState)

-- | UI-level application state.
data AppState = AppState { appAddressBook :: AddressBookState
                         , searchTerm     :: Text
                         }
     deriving (Eq, FromJSON, Generic, Show, ToJSON)

-- | Empty UI-level application state.
emptyAppState :: AppState
emptyAppState =
  AppState
    { appAddressBook = emptyAddressBookState
    , searchTerm = T.empty
    }
