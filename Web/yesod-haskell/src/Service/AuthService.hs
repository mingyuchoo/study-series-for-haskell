{-# LANGUAGE OverloadedStrings #-}

-- | [REQ-F002] 인증 서비스 — 비밀번호 해시 및 검증
module Service.AuthService
  where

import Crypto.BCrypt
  ( hashPasswordUsingPolicy
  , slowerBcryptHashingPolicy
  , validatePassword
  )
import Data.Text (Text)
import Data.Text.Encoding (decodeUtf8, encodeUtf8)

-- | 비밀번호를 BCrypt로 해시
hashPassword :: Text -> IO (Maybe Text)
hashPassword password = do
  mHashed <- hashPasswordUsingPolicy slowerBcryptHashingPolicy (encodeUtf8 password)
  return $ fmap decodeUtf8 mHashed

-- | 비밀번호 검증
verifyPassword :: Text -> Text -> Bool
verifyPassword password hashedPassword =
  validatePassword (encodeUtf8 hashedPassword) (encodeUtf8 password)
