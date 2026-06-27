-- | signup_verifications 테이블 접근. 이메일 인증번호 확인 전까지 가입 정보를
--   임시 보관한다 (확인되면 'Luck.Repository.User.insertUser' 로 승격 후 삭제).
module Luck.Repository.Verification
    ( VerificationRow (..)
    , deleteVerification
    , getVerification
    , upsertVerification
    ) where

import           Data.Pool                          (Pool)
import           Data.Text                          (Text)
import           Data.Time                          (UTCTime)
import           Database.PostgreSQL.Simple
import           Database.PostgreSQL.Simple.FromRow (FromRow (..), field)
import           Luck.DB                            (withConn)

-- | signup_verifications 한 행 (인증 대기 중인 가입 정보).
data VerificationRow = VerificationRow
  { vrEmail        :: Text
  , vrPasswordHash :: Text
  , vrDisplayName  :: Text
  , vrCode         :: Text
  , vrExpiresAt    :: UTCTime
  }

instance FromRow VerificationRow where
  fromRow = VerificationRow <$> field <*> field <*> field <*> field <*> field

-- | 인증 대기 행을 삽입하거나(같은 이메일이 있으면) 덮어쓴다 — 코드 재발급에 해당.
upsertVerification
  :: Pool Connection
  -> Text     -- ^ email
  -> Text     -- ^ password hash
  -> Text     -- ^ display name
  -> Text     -- ^ code
  -> UTCTime  -- ^ expires at
  -> IO ()
upsertVerification pool email pwHash displayName code expiresAt =
  withConn pool $ \c -> do
    _ <-
      execute
        c
        "INSERT INTO signup_verifications (email, password_hash, display_name, code, expires_at)\
        \ VALUES (?, ?, ?, ?, ?)\
        \ ON CONFLICT (email) DO UPDATE SET\
        \   password_hash = EXCLUDED.password_hash,\
        \   display_name  = EXCLUDED.display_name,\
        \   code          = EXCLUDED.code,\
        \   expires_at    = EXCLUDED.expires_at"
        (email, pwHash, displayName, code, expiresAt)
    pure ()

-- | 이메일로 인증 대기 행을 조회한다 (만료 검사는 호출 측에서 수행).
getVerification :: Pool Connection -> Text -> IO (Maybe VerificationRow)
getVerification pool email = withConn pool $ \c -> do
  rows <-
    query
      c
      "SELECT email, password_hash, display_name, code, expires_at\
      \ FROM signup_verifications WHERE email = ?"
      (Only email)
  pure $ case rows of
    (r : _) -> Just r
    []      -> Nothing

-- | 인증 대기 행을 삭제한다 (승격 완료 후 정리).
deleteVerification :: Pool Connection -> Text -> IO ()
deleteVerification pool email = withConn pool $ \c -> do
  _ <- execute c "DELETE FROM signup_verifications WHERE email = ?" (Only email)
  pure ()
