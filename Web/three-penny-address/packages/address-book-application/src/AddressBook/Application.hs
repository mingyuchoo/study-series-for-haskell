module AddressBook.Application
  ( ContactError (..)
  , ContactRepository (..)
  , listContacts
  , removeContact
  , saveContact
  ) where

import AddressBook.Domain.Contact (Contact (..), ContactId)
import AddressBook.Domain.Contacts (addContact, deleteContact, updateContact)
import AddressBook.Domain.Search (searchContacts)
import AddressBook.Domain.State (AddressBookState (..), addressBookToContacts)
import AddressBook.Domain.Validation (ValidationError)
import Data.Bifunctor (first)
import qualified Data.Map as Map
import Data.Text (Text)

data ContactError
  = ValidationFailure [ValidationError]
  | ContactNotFound ContactId
  | PersistenceFailure String
  deriving (Eq, Show)

data ContactRepository m = ContactRepository
  { loadAddressBook :: m (Either ContactError AddressBookState)
  , modifyAddressBook
      :: (AddressBookState -> Either ContactError AddressBookState)
      -> m (Either ContactError AddressBookState)
  }

listContacts :: Text -> AddressBookState -> [Contact]
listContacts query = searchContacts query . addressBookToContacts

saveContact
  :: ContactRepository m
  -> Maybe ContactId
  -> Text
  -> Maybe Text
  -> Maybe Text
  -> Maybe Text
  -> m (Either ContactError AddressBookState)
saveContact repository identifier name phone email address =
  modifyAddressBook repository $ \addressBook ->
    case identifier of
      Nothing ->
        first ValidationFailure $
          addContact (contactWithId (addressNextId addressBook)) addressBook
      Just contactIdentifier
        | Map.member contactIdentifier (addressContacts addressBook) ->
            first ValidationFailure $
              updateContact (contactWithId contactIdentifier) addressBook
        | otherwise -> Left (ContactNotFound contactIdentifier)
  where
    contactWithId contactIdentifier = Contact contactIdentifier name phone email address

removeContact :: ContactRepository m -> ContactId -> m (Either ContactError AddressBookState)
removeContact repository identifier =
  modifyAddressBook repository (Right . deleteContact identifier)
