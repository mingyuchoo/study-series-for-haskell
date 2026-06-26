{-# LANGUAGE DeriveAnyClass #-}

-- | API 경계에서 주고받는 데이터 타입과 JSON 인코딩을 정의한다.
module Luck.Types
    ( -- * JWT 페이로드
      AuthUser (..)
      -- * 인증 요청/응답
    , AuthResp (..)
    , LoginReq (..)
    , SignupReq (..)
      -- * 사용자/프로필
    , ProfileUpdate (..)
    , UserDTO (..)
      -- * 기록
    , RecordDTO (..)
    , RecordUpdate (..)
      -- * 체크리스트 항목 타입 (정본 데이터는 'Luck.Domain.Checklist')
    , CatalogItem (..)
      -- * 공용
    , MessageResp (..)
    ) where

import           Data.Aeson
import           Data.Char        (toLower)
import           Data.Text        (Text)
import           Data.Time        (Day, UTCTime)
import           Data.UUID        (UUID)
import           GHC.Generics     (Generic)
import           Servant.Auth.JWT (FromJWT, ToJWT)

-- | 레코드 필드의 접두사를 떼고 camelCase JSON 키로 변환하는 옵션.
jsonOpts :: String -> Options
jsonOpts prefix =
  defaultOptions
    { fieldLabelModifier = lowerFirst . drop (length prefix)
    , omitNothingFields = True
    }
  where
    lowerFirst []       = []
    lowerFirst (c : cs) = toLower c : cs

-- | JWT 안에 담기는 인증 사용자 정보.
data AuthUser = AuthUser
  { auId    :: UUID
  , auEmail :: Text
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON AuthUser where
  toJSON = genericToJSON (jsonOpts "au")

instance FromJSON AuthUser where
  parseJSON = genericParseJSON (jsonOpts "au")

instance ToJWT AuthUser

instance FromJWT AuthUser

-- | 회원가입 요청 바디.
data SignupReq = SignupReq
  { srEmail       :: Text
  , srPassword    :: Text
  , srDisplayName :: Text
  }
  deriving stock (Show, Generic)

instance FromJSON SignupReq where
  parseJSON = genericParseJSON (jsonOpts "sr")

instance ToJSON SignupReq where
  toJSON = genericToJSON (jsonOpts "sr")

-- | 로그인 요청 바디.
data LoginReq = LoginReq
  { lrEmail    :: Text
  , lrPassword :: Text
  }
  deriving stock (Show, Generic)

instance FromJSON LoginReq where
  parseJSON = genericParseJSON (jsonOpts "lr")

instance ToJSON LoginReq where
  toJSON = genericToJSON (jsonOpts "lr")

-- | 인증 성공 응답: 토큰 + 사용자 정보.
data AuthResp = AuthResp
  { arToken :: Text
  , arUser  :: UserDTO
  }
  deriving stock (Show, Generic)

instance ToJSON AuthResp where
  toJSON = genericToJSON (jsonOpts "ar")

instance FromJSON AuthResp where
  parseJSON = genericParseJSON (jsonOpts "ar")

-- | 클라이언트에 노출되는 사용자/프로필.
data UserDTO = UserDTO
  { udId          :: UUID
  , udEmail       :: Text
  , udDisplayName :: Text
  , udBio         :: Text
  , udTimezone    :: Text
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

-- | 체크리스트 항목 정의.
data CatalogItem = CatalogItem
  { ciKey   :: Text
  , ciLabel :: Text
  }
  deriving stock (Show, Generic)

instance ToJSON CatalogItem where
  toJSON = genericToJSON (jsonOpts "ci")

instance FromJSON CatalogItem where
  parseJSON = genericParseJSON (jsonOpts "ci")

-- | 단순 메시지 응답.
newtype MessageResp = MessageResp {message :: Text}
  deriving stock (Show, Generic)
  deriving anyclass (ToJSON, FromJSON)
