module Services.SearchService
    ( SearchService(..)
    , searchContacts
    , filterContacts
    ) where

import Data.Text (Text)
import qualified Data.Text as T
import Models.Contact (Contact(..))

-- | Interface for contact search functionality
class SearchService m where
    searchContactsM :: Text -> [Contact] -> m [Contact]

-- | Pure search function that filters contacts based on search term
-- Searches across name, phone, and email fields with case-insensitive partial matching
searchContacts :: Text -> [Contact] -> [Contact]
searchContacts searchTerm contacts =
    if T.null normalizedTerm
        then contacts  -- Empty search returns all contacts
        else filter (matchesContact normalizedTerm) contacts
  where
    normalizedTerm = T.toLower (T.strip searchTerm)

-- | Check if a contact matches the search term
matchesContact :: Text -> Contact -> Bool
matchesContact searchTerm contact =
    searchTerm `T.isInfixOf` T.toLower (contactName contact) ||
    maybe False (T.isInfixOf searchTerm . T.toLower) (contactPhone contact) ||
    maybe False (T.isInfixOf searchTerm . T.toLower) (contactEmail contact)

-- | Alias for searchContacts for backward compatibility
filterContacts :: Text -> [Contact] -> [Contact]
filterContacts = searchContacts

-- | Default instance for IO monad
instance SearchService IO where
    searchContactsM = \term contacts -> return (searchContacts term contacts)
