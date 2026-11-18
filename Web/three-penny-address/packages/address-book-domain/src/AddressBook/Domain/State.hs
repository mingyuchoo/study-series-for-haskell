module AddressBook.Domain.State
    ( AddressBookState (..)
    , addressBookFromContacts
    , addressBookToContacts
    , emptyAddressBookState
    , nextContactIdFromContacts
    ) where

import           Data.List      (sortOn)
import           Data.Map       (Map)
import qualified Data.Map       as Map

import           AddressBook.Domain.Contact (Contact (..), ContactId (..))

data AddressBookState = AddressBookState { addressContacts :: Map ContactId Contact
                                         , addressNextId :: ContactId
                                         }
     deriving (Eq, Show)

emptyAddressBookState :: AddressBookState
emptyAddressBookState =
  AddressBookState
    { addressContacts = Map.empty
    , addressNextId = ContactId 1
    }

addressBookFromContacts :: [Contact] -> AddressBookState
addressBookFromContacts contactList =
  AddressBookState
    { addressContacts = Map.fromList [(contactId c, c) | c <- contactList]
    , addressNextId = nextContactIdFromContacts contactList
    }

addressBookToContacts :: AddressBookState -> [Contact]
addressBookToContacts =
  sortOn contactId . Map.elems . addressContacts

nextContactIdFromContacts :: [Contact] -> ContactId
nextContactIdFromContacts [] = ContactId 1
nextContactIdFromContacts contactList =
  ContactId $ (\(ContactId i) -> i + 1) $ maximum $ map contactId contactList
