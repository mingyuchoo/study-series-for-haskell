module AddressBook.JsonRepository.Format (decodeAddressBook, encodeAddressBook) where

import qualified AddressBook.Domain.Contact as Domain
import AddressBook.Domain.State (AddressBookState (..))
import Data.Aeson (FromJSON, ToJSON, eitherDecodeStrict', encode)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Lazy as LazyByteString
import qualified Data.Map as Map
import Data.Text (Text)
import GHC.Generics (Generic)

data StoredContact = StoredContact
  { contactId :: Int
  , contactName :: Text
  , contactPhone :: Maybe Text
  , contactEmail :: Maybe Text
  , contactAddress :: Maybe Text
  }
  deriving (Generic, FromJSON, ToJSON)

data ContactStore = ContactStore
  { contacts :: [(Int, StoredContact)]
  , nextId :: Int
  }
  deriving (Generic, FromJSON, ToJSON)

decodeAddressBook :: ByteString.ByteString -> Either String AddressBookState
decodeAddressBook = fmap fromStore . eitherDecodeStrict'

encodeAddressBook :: AddressBookState -> LazyByteString.ByteString
encodeAddressBook = encode . toStore

fromStore :: ContactStore -> AddressBookState
fromStore store =
  AddressBookState
    (Map.fromList [(Domain.ContactId key, fromStoredContact contact) | (key, contact) <- contacts store])
    (Domain.ContactId (nextId store))

fromStoredContact :: StoredContact -> Domain.Contact
fromStoredContact (StoredContact identifier name phone email address) =
  Domain.Contact (Domain.ContactId identifier) name phone email address

toStore :: AddressBookState -> ContactStore
toStore (AddressBookState entries (Domain.ContactId nextIdentifier)) =
  ContactStore
    [(key, toStoredContact contact) | (Domain.ContactId key, contact) <- Map.toAscList entries]
    nextIdentifier

toStoredContact :: Domain.Contact -> StoredContact
toStoredContact (Domain.Contact (Domain.ContactId identifier) name phone email address) =
  StoredContact identifier name phone email address
