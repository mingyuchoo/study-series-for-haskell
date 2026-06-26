-- | 일별 기록 경계 타입 (DTO).
module Luck.Types.Record
    ( RecordDTO (..)
    , RecordUpdate (..)
    ) where

import           Data.Aeson
import           Data.Text         (Text)
import           Data.Time         (Day)
import           GHC.Generics      (Generic)
import           Luck.Types.Common (jsonOpts)

-- | 하루치 기록.
data RecordDTO = RecordDTO
  { rdDate      :: Day
  , rdCompleted :: [Text]
  , rdNote      :: Maybe Text
  , rdTotal     :: Int
  -- ^ 전체 항목 수 (달력에서 달성률 계산용)
  }
  deriving stock (Show, Generic)

instance ToJSON RecordDTO where
  toJSON = genericToJSON (jsonOpts "rd")

instance FromJSON RecordDTO where
  parseJSON = genericParseJSON (jsonOpts "rd")

-- | 하루치 기록 저장 요청.
data RecordUpdate = RecordUpdate
  { ruCompleted :: [Text]
  , ruNote      :: Maybe Text
  }
  deriving stock (Show, Generic)

instance FromJSON RecordUpdate where
  parseJSON = genericParseJSON (jsonOpts "ru")

instance ToJSON RecordUpdate where
  toJSON = genericToJSON (jsonOpts "ru")
