-- | signup_verifications 테이블 접근. 이메일 인증번호 확인 전까지 가입 정보를
--   임시 보관한다 (확인되면 'Luck.Repository.User.insertUser' 로 승격 후 삭제).
module Luck.Repository.Verification
    ( VerificationRow (..)
    , consumeVerificationAttempt
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
        \   expires_at    = EXCLUDED.expires_at,\
        \   attempts      = 0"
        (email, pwHash, displayName, code, expiresAt)
    pure ()

-- | verify 시도를 원자적으로 1회 소비한다. 남은 시도가 있으면(attempts < maxAttempts)
--   attempts 를 1 증가시키고 행을 돌려준다. 남은 시도가 없거나 행이 없으면 'Nothing'.
--
--   조건부 UPDATE 한 문장으로 처리하므로 동시 요청에서도 행 잠금이 직렬화돼
--   상한을 정확히 지킨다(TOCTOU 없음). 미존재/잠김 구분은 호출 측이
--   'getVerification' 으로 따로 확인한다(보안이 아닌 메시지/로그용).
consumeVerificationAttempt
  :: Pool Connection -> Text -> Int -> IO (Maybe VerificationRow)
consumeVerificationAttempt pool email maxAttempts = withConn pool $ \c -> do
  rows <-
    query
      c
      "UPDATE signup_verifications SET attempts = attempts + 1\
      \ WHERE email = ? AND attempts < ?\
      \ RETURNING email, password_hash, display_name, code, expires_at"
      (email, maxAttempts)
  pure $ case rows of
    (r : _) -> Just r
    []      -> Nothing

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
