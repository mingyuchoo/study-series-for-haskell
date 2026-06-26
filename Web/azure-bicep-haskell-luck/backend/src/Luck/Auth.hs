-- | 비밀번호 해싱/검증과 JWT 토큰 발급 헬퍼.
module Luck.Auth
    ( hashPassword
    , issueToken
    , jwtSettingsFromSecret
    , verifyPassword
    ) where

import           Crypto.BCrypt
    ( hashPasswordUsingPolicy
    , slowerBcryptHashingPolicy
    , validatePassword
    )
import           Crypto.Hash          (SHA256 (..), hashWith)
import qualified Data.ByteArray       as BA
import           Data.ByteString      (ByteString)
import qualified Data.ByteString.Lazy as BL
import           Data.Text            (Text)
import qualified Data.Text.Encoding   as TE
import           Data.Time            (addUTCTime, getCurrentTime, nominalDay)
import           Luck.Types           (AuthUser)
import           Servant.Auth.Server
    ( JWTSettings
    , defaultJWTSettings
    , fromSecret
    , makeJWT
    )

-- | 평문 비밀번호를 bcrypt 해시(텍스트)로 만든다. 실패 시 'Nothing'.
hashPassword :: Text -> IO (Maybe Text)
hashPassword pw = do
  mh <- hashPasswordUsingPolicy slowerBcryptHashingPolicy (TE.encodeUtf8 pw)
  pure (TE.decodeUtf8 <$> mh)

-- | 평문 비밀번호가 저장된 해시와 일치하는지 검증한다.
verifyPassword :: Text -> Text -> Bool
verifyPassword pw stored =
  validatePassword (TE.encodeUtf8 stored) (TE.encodeUtf8 pw)

-- | 임의 길이의 시크릿으로 'JWTSettings' 를 만든다.
--
-- HMAC 서명(HS256)에는 최소 32바이트 키가 필요하다. 환경변수로 받은 시크릿이
-- 짧으면 'makeJWT' 가 'KeySizeTooSmall' 로 실패하므로, SHA-256 으로 항상 32바이트
-- 키를 파생시켜 어떤 길이의 시크릿이든 안전하게 동작하도록 한다.
jwtSettingsFromSecret :: ByteString -> JWTSettings
jwtSettingsFromSecret secret =
  defaultJWTSettings (fromSecret key)
  where
    key = BA.convert (hashWith SHA256 secret)

-- | 7일 만료의 JWT를 발급한다. 실패 시 'Nothing'.
issueToken :: JWTSettings -> AuthUser -> IO (Maybe Text)
issueToken jwtCfg user = do
  now <- getCurrentTime
  let expiry = addUTCTime (7 * nominalDay) now
  eTok <- makeJWT user jwtCfg (Just expiry)
  pure $ case eTok of
    Left _   -> Nothing
    Right bs -> Just (TE.decodeUtf8 (BL.toStrict bs))
