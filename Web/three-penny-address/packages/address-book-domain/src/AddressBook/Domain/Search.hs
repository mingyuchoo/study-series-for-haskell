module AddressBook.Domain.Search
    ( searchContacts
    ) where

import           Data.Text      (Text)
import qualified Data.Text      as T

import           AddressBook.Domain.Contact (Contact (..))

searchContacts :: Text -> [Contact] -> [Contact]
searchContacts searchTerm contacts =
  if T.null normalizedTerm
    then contacts
    else filter (matchesContact normalizedTerm) contacts
  where
    normalizedTerm = T.toLower (T.strip searchTerm)

matchesContact :: Text -> Contact -> Bool
matchesContact searchTerm contact =
  searchTerm `T.isInfixOf` T.toLower (contactName contact)
    || maybe False (T.isInfixOf searchTerm . T.toLower) (contactPhone contact)
    || maybe False (T.isInfixOf searchTerm . T.toLower) (contactEmail contact)
