-- | 비밀번호 해싱/검증과 JWT 토큰 발급 헬퍼.
module Luck.Auth
  ( hashPassword
  , verifyPassword
  , issueToken
  ) where

import Crypto.BCrypt (hashPasswordUsingPolicy, slowerBcryptHashingPolicy, validatePassword)
import Data.ByteString.Lazy qualified as BL
import Data.Text (Text)
import Data.Text.Encoding qualified as TE
import Data.Time (addUTCTime, getCurrentTime, nominalDay)
import Luck.Types (AuthUser)
import Servant.Auth.Server (JWTSettings, makeJWT)

-- | 평문 비밀번호를 bcrypt 해시(텍스트)로 만든다. 실패 시 'Nothing'.
hashPassword :: Text -> IO (Maybe Text)
hashPassword pw = do
  mh <- hashPasswordUsingPolicy slowerBcryptHashingPolicy (TE.encodeUtf8 pw)
  pure (TE.decodeUtf8 <$> mh)

-- | 평문 비밀번호가 저장된 해시와 일치하는지 검증한다.
verifyPassword :: Text -> Text -> Bool
verifyPassword pw stored =
  validatePassword (TE.encodeUtf8 stored) (TE.encodeUtf8 pw)

-- | 7일 만료의 JWT를 발급한다. 실패 시 'Nothing'.
issueToken :: JWTSettings -> AuthUser -> IO (Maybe Text)
issueToken jwtCfg user = do
  now <- getCurrentTime
  let expiry = addUTCTime (7 * nominalDay) now
  eTok <- makeJWT user jwtCfg (Just expiry)
  pure $ case eTok of
    Left _ -> Nothing
    Right bs -> Just (TE.decodeUtf8 (BL.toStrict bs))
