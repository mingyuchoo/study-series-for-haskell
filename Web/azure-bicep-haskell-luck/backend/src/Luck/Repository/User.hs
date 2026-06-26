{-# LANGUAGE QuasiQuotes #-}

-- | users 테이블 접근. DB 행 표현('UserRow')과 쿼리를 캡슐화한다.
--   외부 DTO/HTTP는 모른다 (변환은 'Luck.Web.Dto').
module Luck.Repository.User
    ( UserRow (..)
    , getUserByEmail
    , getUserById
    , insertUser
    , updateProfile
    ) where

import           Control.Exception                  (try)
import           Data.Pool                          (Pool)
import           Data.Text                          (Text)
import           Data.Time                          (UTCTime)
import           Data.UUID                          (UUID)
import           Database.PostgreSQL.Simple
import           Database.PostgreSQL.Simple.FromRow (FromRow (..), field)
import           Luck.DB                            (withConn)
import           Luck.Error                         (DomainError (..))

-- | DB의 users 한 행 (비밀번호 해시 포함, 외부로 노출하지 않음).
data UserRow = UserRow
  { urId           :: UUID
  , urEmail        :: Text
  , urPasswordHash :: Text
  , urDisplayName  :: Text
  , urBio          :: Text
  , urTimezone     :: Text
  , urIsAdmin      :: Bool
  , urCreatedAt    :: UTCTime
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
      <*> field

-- | 새 사용자를 삽입한다. 이메일 중복(23505)이면 @Left EmailTaken@.
--   DB에 사용자가 한 명도 없을 때(=최초 가입자)는 자동으로 관리자가 된다.
--   COUNT는 삽입 전 상태를 보므로 같은 문장 안에서 안전하게 판정된다.
insertUser
  :: Pool Connection -> UUID -> Text -> Text -> Text -> IO (Either DomainError UserRow)
insertUser pool uid email pwHash displayName = withConn pool $ \c -> do
  res <-
    try $
      query
        c
        "INSERT INTO users (id, email, password_hash, display_name, is_admin)\
        \ VALUES (?, ?, ?, ?, (SELECT COUNT(*) = 0 FROM users))\
        \ RETURNING id, email, password_hash, display_name, bio, timezone, is_admin, created_at"
        (uid, email, pwHash, displayName)
  case res of
    Left e
      | sqlState e == "23505" -> pure (Left EmailTaken)
      | otherwise -> pure (Left (InternalError "가입 중 오류가 발생했습니다."))
    Right [row] -> pure (Right row)
    Right _ -> pure (Left (InternalError "가입 처리에 실패했습니다."))

-- | 이메일로 사용자를 조회한다.
getUserByEmail :: Pool Connection -> Text -> IO (Maybe UserRow)
getUserByEmail pool email = withConn pool $ \c -> do
  rows <-
    query
      c
      "SELECT id, email, password_hash, display_name, bio, timezone, is_admin, created_at\
      \ FROM users WHERE email = ?"
      (Only email)
  pure (listToMaybe' rows)

-- | ID로 사용자를 조회한다.
getUserById :: Pool Connection -> UUID -> IO (Maybe UserRow)
getUserById pool uid = withConn pool $ \c -> do
  rows <-
    query
      c
      "SELECT id, email, password_hash, display_name, bio, timezone, is_admin, created_at\
      \ FROM users WHERE id = ?"
      (Only uid)
  pure (listToMaybe' rows)

-- | 프로필 필드를 갱신하고 갱신된 행을 돌려준다.
updateProfile
  :: Pool Connection -> UUID -> Text -> Text -> Text -> IO (Maybe UserRow)
updateProfile pool uid displayName bio timezone = withConn pool $ \c -> do
  rows <-
    query
      c
      "UPDATE users SET display_name = ?, bio = ?, timezone = ?\
      \ WHERE id = ?\
      \ RETURNING id, email, password_hash, display_name, bio, timezone, is_admin, created_at"
      (displayName, bio, timezone, uid)
  pure (listToMaybe' rows)

-- | 안전한 head.
listToMaybe' :: [a] -> Maybe a
listToMaybe' []      = Nothing
listToMaybe' (x : _) = Just x
