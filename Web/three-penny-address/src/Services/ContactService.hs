module Services.ContactService
    ( ContactService (..)
    , addContact
    , deleteContact
    , generateNextId
    , updateContact
    ) where

import qualified Data.Map                   as Map

import           Models.AddressBookState    (AddressBookState (..))
import           Models.Contact             (Contact (..), ContactId (..))

import           Services.ValidationService (ValidationError,
                                             validateContactData)

-- | Interface for contact management operations
class ContactService m where
  addContactM
    :: Contact -> AddressBookState -> m (Either [ValidationError] AddressBookState)
  updateContactM
    :: Contact -> AddressBookState -> m (Either [ValidationError] AddressBookState)
  deleteContactM :: ContactId -> AddressBookState -> m AddressBookState

-- | Add a new contact to the address book.
-- Validates the contact data and assigns a new unique ID
addContact :: Contact -> AddressBookState -> Either [ValidationError] AddressBookState
addContact contactData addressBook = do
  -- First validate the contact data
  validatedContact <- validateContactData contactData

  -- Generate new ID and create contact with that ID
  let newId = addressNextId addressBook
      newContact = validatedContact {contactId = newId}
      updatedContacts = Map.insert newId newContact (addressContacts addressBook)
      updatedAddressBook =
        addressBook
          { addressContacts = updatedContacts
          , addressNextId = generateNextId newId
          }

  return updatedAddressBook

-- | Update an existing contact while preserving its ID
-- Validates the updated contact data
updateContact :: Contact -> AddressBookState -> Either [ValidationError] AddressBookState
updateContact updatedContact addressBook = do
  -- Validate the updated contact data
  validatedContact <- validateContactData updatedContact

  -- Check if contact exists
  let contactExists = Map.member (contactId validatedContact) (addressContacts addressBook)

  if contactExists
    then do
      let updatedContacts = Map.insert (contactId validatedContact) validatedContact (addressContacts addressBook)
          updatedAddressBook = addressBook {addressContacts = updatedContacts}
      return updatedAddressBook
    else do
      -- If contact doesn't exist, we could either error or treat as add
      -- For now, we'll just update the map (which will add if not present)
      let updatedContacts = Map.insert (contactId validatedContact) validatedContact (addressContacts addressBook)
          updatedAddressBook = addressBook {addressContacts = updatedContacts}
      return updatedAddressBook

-- | Delete a contact from the address book.
-- Returns the updated state with the contact removed.
deleteContact :: ContactId -> AddressBookState -> AddressBookState
deleteContact contactIdToDelete addressBook =
  let updatedContacts = Map.delete contactIdToDelete (addressContacts addressBook)
      updatedAddressBook = addressBook {addressContacts = updatedContacts}
   in updatedAddressBook

-- | Generate the next unique ContactId
generateNextId :: ContactId -> ContactId
generateNextId (ContactId currentId) = ContactId (currentId + 1)
