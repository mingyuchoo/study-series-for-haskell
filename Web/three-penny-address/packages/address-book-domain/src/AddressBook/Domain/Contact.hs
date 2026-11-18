module AddressBook.Domain.Contact
    ( Contact (..)
    , ContactId (..)
    ) where

import           Data.Text    (Text)

newtype ContactId = ContactId Int
     deriving (Eq, Ord, Show)

data Contact = Contact { contactId      :: ContactId
                       , contactName    :: Text
                       , contactPhone   :: Maybe Text
                       , contactEmail   :: Maybe Text
                       , contactAddress :: Maybe Text
                       }
     deriving (Eq, Show)
