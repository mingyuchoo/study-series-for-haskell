module Models.Contact
    ( Contact(..)
    , ContactId(..)
    ) where

import Data.Aeson (FromJSON, ToJSON, FromJSONKey, ToJSONKey)
import Data.Text (Text)
import GHC.Generics (Generic)

-- | Unique identifier for contacts
newtype ContactId = ContactId Int
    deriving (Show, Eq, Ord, Generic, FromJSON, ToJSON, FromJSONKey, ToJSONKey)

-- | Contact data model
data Contact = Contact
    { contactId      :: ContactId
    , contactName    :: Text
    , contactPhone   :: Maybe Text
    , contactEmail   :: Maybe Text
    , contactAddress :: Maybe Text
    } deriving (Show, Eq, Generic, FromJSON, ToJSON)