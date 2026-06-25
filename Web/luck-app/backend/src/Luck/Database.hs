{-# LANGUAGE QuasiQuotes #-}

-- | PostgreSQL 접근 계층. 커넥션 풀과 모든 SQL 쿼리를 캡슐화한다.
module Luck.Database
  ( -- * 풀
    newConnPool
  , initSchema

    -- * 내부 행 타입
  , UserRow (..)
  , userRowToDTO

    -- * 사용자 쿼리
  , insertUser
  , getUserByEmail
  , getUserById
  , updateProfile

    -- * 기록 쿼리
  , getRecord
  , getRecordsBetween
  , upsertRecord
  ) where

import Control.Exception (try)
import Data.ByteString (ByteString)
import Data.Pool (Pool, defaultPoolConfig, newPool, withResource)
import Data.Text (Text)
import Data.Time (Day, UTCTime)
import Data.UUID (UUID)
import Database.PostgreSQL.Simple
import Database.PostgreSQL.Simple.FromRow (FromRow (..), field)
import Database.PostgreSQL.Simple.Newtypes (Aeson (..))
import Luck.Types

-- | DB의 users 한 행 (비밀번호 해시 포함, 외부로 노출하지 않음).
data UserRow = UserRow
  { urId :: UUID
  , urEmail :: Text
  , urPasswordHash :: Text
  , urDisplayName :: Text
  , urBio :: Text
  , urTimezone :: Text
  , urCreatedAt :: UTCTime
  }

instance FromRow UserRow where
  fromRow =
    UserRow
      <$> field
      <*> field
      <*> field
      <*> field
      <*> field
      <*> field
      <*> field

-- | 내부 행을 외부 DTO로 변환 (비밀번호 해시 제거).
userRowToDTO :: UserRow -> UserDTO
userRowToDTO UserRow{..} =
  UserDTO
    { udId = urId
    , udEmail = urEmail
    , udDisplayName = urDisplayName
    , udBio = urBio
    , udTimezone = urTimezone
    , udCreatedAt = urCreatedAt
    }

-- | libpq 접속 문자열로 커넥션 풀을 만든다.
newConnPool :: ByteString -> IO (Pool Connection)
newConnPool url =
  newPool (defaultPoolConfig (connectPostgreSQL url) close 60 10)

-- | 풀에서 커넥션을 빌려 작업을 실행한다.
withConn :: Pool Connection -> (Connection -> IO a) -> IO a
withConn = withResource

-- | 스키마를 멱등적으로 생성한다 (서버 기동 시 자동 호출).
initSchema :: Pool Connection -> IO ()
initSchema pool = withConn pool $ \c -> do
  _ <-
    execute_
      c
      "CREATE TABLE IF NOT EXISTS users (\
      \ id uuid PRIMARY KEY,\
      \ email text NOT NULL UNIQUE,\
      \ password_hash text NOT NULL,\
      \ display_name text NOT NULL,\
      \ bio text NOT NULL DEFAULT '',\
      \ timezone text NOT NULL DEFAULT 'Asia/Seoul',\
      \ created_at timestamptz NOT NULL DEFAULT now())"
  _ <-
    execute_
      c
      "CREATE TABLE IF NOT EXISTS daily_records (\
      \ user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,\
      \ record_date date NOT NULL,\
      \ completed jsonb NOT NULL DEFAULT '[]'::jsonb,\
      \ note text,\
      \ updated_at timestamptz NOT NULL DEFAULT now(),\
      \ PRIMARY KEY (user_id, record_date))"
  pure ()

-- | 새 사용자를 삽입한다. 이메일 중복(23505)이면 @Left "email_taken"@.
insertUser :: Pool Connection -> UUID -> Text -> Text -> Text -> IO (Either Text UserRow)
insertUser pool uid email pwHash displayName = withConn pool $ \c -> do
  res <-
    try $
      query
        c
        "INSERT INTO users (id, email, password_hash, display_name)\
        \ VALUES (?, ?, ?, ?)\
        \ RETURNING id, email, password_hash, display_name, bio, timezone, created_at"
        (uid, email, pwHash, displayName)
  case res of
    Left e
      | sqlState e == "23505" -> pure (Left "email_taken")
      | otherwise -> pure (Left (sqlErrorMsg e))
    Right [row] -> pure (Right row)
    Right _ -> pure (Left "insert_failed")
  where
    sqlErrorMsg :: SqlError -> Text
    sqlErrorMsg = const "db_error"

-- | 이메일로 사용자를 조회한다.
getUserByEmail :: Pool Connection -> Text -> IO (Maybe UserRow)
getUserByEmail pool email = withConn pool $ \c -> do
  rows <-
    query
      c
      "SELECT id, email, password_hash, display_name, bio, timezone, created_at\
      \ FROM users WHERE email = ?"
      (Only email)
  pure (listToMaybe rows)

-- | ID로 사용자를 조회한다.
getUserById :: Pool Connection -> UUID -> IO (Maybe UserRow)
getUserById pool uid = withConn pool $ \c -> do
  rows <-
    query
      c
      "SELECT id, email, password_hash, display_name, bio, timezone, created_at\
      \ FROM users WHERE id = ?"
      (Only uid)
  pure (listToMaybe rows)

-- | 프로필 필드를 갱신하고 갱신된 행을 돌려준다.
updateProfile :: Pool Connection -> UUID -> ProfileUpdate -> IO (Maybe UserRow)
updateProfile pool uid ProfileUpdate{..} = withConn pool $ \c -> do
  rows <-
    query
      c
      "UPDATE users SET display_name = ?, bio = ?, timezone = ?\
      \ WHERE id = ?\
      \ RETURNING id, email, password_hash, display_name, bio, timezone, created_at"
      (puDisplayName, puBio, puTimezone, uid)
  pure (listToMaybe rows)

-- | 특정 날짜의 기록을 조회한다.
getRecord :: Pool Connection -> UUID -> Day -> IO (Maybe (Day, [Text], Maybe Text))
getRecord pool uid d = withConn pool $ \c -> do
  rows <-
    query
      c
      "SELECT record_date, completed, note FROM daily_records\
      \ WHERE user_id = ? AND record_date = ?"
      (uid, d)
  pure (fmap unwrap (listToMaybe rows))
  where
    unwrap (rd, Aeson cs, note) = (rd, cs, note)

-- | 기간 내 기록 목록을 조회한다 (달력용).
getRecordsBetween :: Pool Connection -> UUID -> Day -> Day -> IO [(Day, [Text], Maybe Text)]
getRecordsBetween pool uid from to = withConn pool $ \c -> do
  rows <-
    query
      c
      "SELECT record_date, completed, note FROM daily_records\
      \ WHERE user_id = ? AND record_date BETWEEN ? AND ?\
      \ ORDER BY record_date"
      (uid, from, to)
  pure (map unwrap rows)
  where
    unwrap (rd, Aeson cs, note) = (rd, cs, note)

-- | 하루치 기록을 upsert 하고 저장된 결과를 돌려준다.
upsertRecord
  :: Pool Connection -> UUID -> Day -> [Text] -> Maybe Text -> IO (Day, [Text], Maybe Text)
upsertRecord pool uid d completed note = withConn pool $ \c -> do
  rows <-
    query
      c
      "INSERT INTO daily_records (user_id, record_date, completed, note, updated_at)\
      \ VALUES (?, ?, ?, ?, now())\
      \ ON CONFLICT (user_id, record_date)\
      \ DO UPDATE SET completed = EXCLUDED.completed, note = EXCLUDED.note, updated_at = now()\
      \ RETURNING record_date, completed, note"
      (uid, d, Aeson completed, note)
  case rows of
    ((rd, Aeson cs, n) : _) -> pure (rd, cs, n)
    [] -> pure (d, completed, note)

-- | 안전한 head.
listToMaybe :: [a] -> Maybe a
listToMaybe [] = Nothing
listToMaybe (x : _) = Just x
