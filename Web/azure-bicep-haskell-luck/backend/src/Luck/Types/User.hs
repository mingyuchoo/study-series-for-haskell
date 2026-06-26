-- | 사용자/프로필 경계 타입 (DTO).
module Luck.Types.User
    ( ProfileUpdate (..)
    , UserDTO (..)
    ) where

import           Data.Aeson
import           Data.Text         (Text)
import           Data.Time         (UTCTime)
import           Data.UUID         (UUID)
import           GHC.Generics      (Generic)
import           Luck.Types.Common (jsonOpts)

-- | 클라이언트에 노출되는 사용자/프로필.
data UserDTO = UserDTO
  { udId          :: UUID
  , udEmail       :: Text
  , udDisplayName :: Text
  , udBio         :: Text
  , udTimezone    :: Text
  , udIsAdmin     :: Bool
  , udCreatedAt   :: UTCTime
  }
  deriving stock (Show, Generic)

instance ToJSON UserDTO where
  toJSON = genericToJSON (jsonOpts "ud")

instance FromJSON UserDTO where
  parseJSON = genericParseJSON (jsonOpts "ud")

-- | 프로필 수정 요청.
data ProfileUpdate = ProfileUpdate
  { puDisplayName :: Text
  , puBio         :: Text
  , puTimezone    :: Text
  }
  deriving stock (Show, Generic)

instance FromJSON ProfileUpdate where
  parseJSON = genericParseJSON (jsonOpts "pu")

instance ToJSON ProfileUpdate where
  toJSON = genericToJSON (jsonOpts "pu")
