module Services.ContactRepository
    ( ContactRepository (..)
    , FileContactRepository (..)
    , loadAddressBookFromFile
    , loadContactsFromFile
    , saveAddressBookToFile
    , saveContactsToFile
    ) where

import           Control.Exception       (IOException, try)

import           Data.Aeson              (FromJSON, ToJSON,
                                          eitherDecodeFileStrict, encodeFile)
import qualified Data.Map                as Map

import           GHC.Generics            (Generic)

import           Models.AddressBookState (AddressBookState (..),
                                          addressBookFromContacts,
                                          addressBookToContacts)
import           Models.Contact          (Contact (..), ContactId (..))

import           System.Directory        (doesFileExist)

-- | Persistence-only JSON shape.
data ContactStore = ContactStore { contacts :: Map.Map ContactId Contact
                                 , nextId   :: ContactId
                                 }
     deriving (Eq, FromJSON, Generic, Show, ToJSON)

-- | Interface for contact data persistence
class ContactRepository m where
  loadContacts :: m (Either String [Contact])
  saveContacts :: [Contact] -> m (Either String ())

-- | File-based implementation of ContactRepository
data FileContactRepository = FileContactRepository { repositoryFilePath :: FilePath
                                                   }
     deriving (Eq, Show)

-- | Load contacts from JSON file
loadAddressBookFromFile :: FilePath -> IO (Either String AddressBookState)
loadAddressBookFromFile filePath = do
  fileExists <- doesFileExist filePath
  if not fileExists
    then return $ Right $ addressBookFromContacts []
    else do
      result <- try $ (eitherDecodeFileStrict filePath :: IO (Either String ContactStore))
      case result of
        Left (ioErr :: IOException) ->
          return $ Left $ "IO Error reading file: " ++ show ioErr
        Right (Left jsonErr) ->
          return $ Left $ "JSON parsing error: " ++ jsonErr
        Right (Right contactStore) ->
          return $
            Right $
              AddressBookState
                { addressContacts = contacts contactStore
                , addressNextId = nextId contactStore
                }

-- | Save address book state to JSON file.
saveAddressBookToFile :: FilePath -> AddressBookState -> IO (Either String ())
saveAddressBookToFile filePath addressBook = do
  let contactStore =
        ContactStore
          { contacts = addressContacts addressBook
          , nextId = addressNextId addressBook
          }
  result <- try $ encodeFile filePath contactStore
  case result of
    Left (ioErr :: IOException) ->
      return $ Left $ "IO Error writing file: " ++ show ioErr
    Right () ->
      return $ Right ()

-- | Load contacts from JSON file.
loadContactsFromFile :: FilePath -> IO (Either String [Contact])
loadContactsFromFile filePath = do
  result <- loadAddressBookFromFile filePath
  return $ addressBookToContacts <$> result

-- | Save contacts to JSON file
saveContactsToFile :: FilePath -> [Contact] -> IO (Either String ())
saveContactsToFile filePath contactList =
  saveAddressBookToFile filePath $ addressBookFromContacts contactList

-- | Instance for IO monad
instance ContactRepository IO where
  loadContacts = loadContactsFromFile "contacts.json"
  saveContacts = saveContactsToFile "contacts.json"
