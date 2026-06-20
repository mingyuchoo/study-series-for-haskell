module Models.AddressBookState
    ( AddressBookState (..)
    , addressBookFromContacts
    , addressBookToContacts
    , emptyAddressBookState
    , nextContactIdFromContacts
    ) where

import           Data.Aeson     (FromJSON, ToJSON)
import           Data.List      (sortOn)
import           Data.Map       (Map)
import qualified Data.Map       as Map

import           GHC.Generics   (Generic)

import           Models.Contact (Contact (..), ContactId (..))

-- | Domain state for contact management.
data AddressBookState = AddressBookState { addressContacts :: Map ContactId Contact
                                         , addressNextId :: ContactId
                                         }
     deriving (Eq, FromJSON, Generic, Show, ToJSON)

-- | Empty address book state.
emptyAddressBookState :: AddressBookState
emptyAddressBookState =
  AddressBookState
    { addressContacts = Map.empty
    , addressNextId = ContactId 1
    }

-- | Build domain state from persisted contacts.
addressBookFromContacts :: [Contact] -> AddressBookState
addressBookFromContacts contactList =
  AddressBookState
    { addressContacts = Map.fromList [(contactId c, c) | c <- contactList]
    , addressNextId = nextContactIdFromContacts contactList
    }

-- | Return contacts in stable id order.
addressBookToContacts :: AddressBookState -> [Contact]
addressBookToContacts =
  sortOn contactId . Map.elems . addressContacts

-- | Compute the next available contact id from existing contacts.
nextContactIdFromContacts :: [Contact] -> ContactId
nextContactIdFromContacts [] = ContactId 1
nextContactIdFromContacts contactList =
  ContactId $ (\(ContactId i) -> i + 1) $ maximum $ map contactId contactList
