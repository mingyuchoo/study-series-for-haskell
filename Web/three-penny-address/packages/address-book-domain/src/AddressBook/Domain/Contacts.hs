module AddressBook.Domain.Contacts
    ( addContact
    , deleteContact
    , generateNextId
    , updateContact
    ) where

import qualified Data.Map                   as Map

import           AddressBook.Domain.State    (AddressBookState (..))
import           AddressBook.Domain.Contact             (Contact (..), ContactId (..))

import           AddressBook.Domain.Validation (ValidationError,
                                             validateContactData)

addContact :: Contact -> AddressBookState -> Either [ValidationError] AddressBookState
addContact contactData addressBook = do
  validatedContact <- validateContactData contactData

  let newId = addressNextId addressBook
      newContact = validatedContact {contactId = newId}
      updatedContacts = Map.insert newId newContact (addressContacts addressBook)
      updatedAddressBook =
        addressBook
          { addressContacts = updatedContacts
          , addressNextId = generateNextId newId
          }

  return updatedAddressBook

updateContact :: Contact -> AddressBookState -> Either [ValidationError] AddressBookState
updateContact updatedContact addressBook = do
  validatedContact <- validateContactData updatedContact

  pure addressBook
    { addressContacts = Map.insert (contactId validatedContact) validatedContact (addressContacts addressBook)
    }

deleteContact :: ContactId -> AddressBookState -> AddressBookState
deleteContact contactIdToDelete addressBook =
  let updatedContacts = Map.delete contactIdToDelete (addressContacts addressBook)
      updatedAddressBook = addressBook {addressContacts = updatedContacts}
   in updatedAddressBook

generateNextId :: ContactId -> ContactId
generateNextId (ContactId currentId) = ContactId (currentId + 1)
