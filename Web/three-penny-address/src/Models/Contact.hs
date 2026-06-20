module Models.Contact
    ( Contact (..)
    , ContactId (..)
    ) where

import           Data.Aeson   (FromJSON, FromJSONKey, ToJSON, ToJSONKey)
import           Data.Text    (Text)

import           GHC.Generics (Generic)

-- | Unique identifier for contacts
newtype ContactId = ContactId Int
     deriving (Eq, FromJSON, FromJSONKey, Generic, Ord, Show, ToJSON, ToJSONKey)

-- | Contact data model
data Contact = Contact { contactId      :: ContactId
                       , contactName    :: Text
                       , contactPhone   :: Maybe Text
                       , contactEmail   :: Maybe Text
                       , contactAddress :: Maybe Text
                       }
     deriving (Eq, FromJSON, Generic, Show, ToJSON)
