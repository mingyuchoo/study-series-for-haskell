-- | 인증 경계 타입: JWT 페이로드와 회원가입/로그인 요청·응답 DTO.
module Luck.Types.Auth
    ( -- * JWT 페이로드
      AuthUser (..)
      -- * 인증 요청/응답
    , AuthResp (..)
    , LoginReq (..)
    , SignupReq (..)
    ) where

import           Data.Aeson
import           Data.Text         (Text)
import           Data.UUID         (UUID)
import           GHC.Generics      (Generic)
import           Luck.Types.Common (jsonOpts)
import           Luck.Types.User   (UserDTO)
import           Servant.Auth.JWT  (FromJWT, ToJWT)

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
