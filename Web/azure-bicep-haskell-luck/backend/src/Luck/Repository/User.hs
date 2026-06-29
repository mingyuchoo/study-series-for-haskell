{-# LANGUAGE QuasiQuotes #-}

-- | users 테이블 접근. DB 행 표현('UserRow')과 쿼리를 캡슐화한다.
--   외부 DTO/HTTP는 모른다 (변환은 'Luck.Web.Dto').
module Luck.Repository.User
    ( UserRow (..)
    , getUserByEmail
    , getUserById
    , insertUser
    , promoteAdmins
    , updateProfile
    , userIsAdmin
    ) where

import           Control.Exception                  (try)
import           Control.Monad                      (unless)
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
  , urThemeKey     :: Text
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
      <*> field

-- | users 행을 읽는 컬럼 목록(단일 출처). 순서는 위 'FromRow' 의 field 순서와
--   반드시 일치해야 한다 — 둘을 나란히 두어 함께 바꾸도록 한다.
--   모든 SELECT/RETURNING 이 이 상수를 재사용해, 컬럼 추가 시 한 곳만 고치면 된다.
userColumns :: Query
userColumns =
  "id, email, password_hash, display_name, bio, timezone, is_admin, created_at, theme_key"

-- | 새 사용자를 삽입한다. 이메일 중복(23505)이면 @Left EmailTaken@.
--
--   관리자 부여 규칙 (호출 측에서 정책 결정):
--     * @explicitAdmin@  : 이메일이 ADMIN_EMAILS 화이트리스트에 있음 → 관리자.
--     * @firstUserFallback@: ADMIN_EMAILS 미설정 시에만 켜지는 "첫 가입자=관리자"
--       폴백. ADMIN_EMAILS가 설정되면 꺼져, 공격자가 먼저 가입해 관리자가 되는
--       레이스를 막는다. COUNT는 삽입 전 상태를 보므로 같은 문장에서 안전하다.
insertUser
  :: Pool Connection
  -> UUID
  -> Text
  -> Text
  -> Text
  -> Bool  -- ^ explicitAdmin
  -> Bool  -- ^ firstUserFallback
  -> IO (Either DomainError UserRow)
insertUser pool uid email pwHash displayName explicitAdmin firstUserFallback =
  withConn pool $ \c -> do
    res <-
      try $
        query
          c
          ( "INSERT INTO users (id, email, password_hash, display_name, is_admin)\
            \ VALUES (?, ?, ?, ?, (? OR (? AND (SELECT COUNT(*) = 0 FROM users))))\
            \ RETURNING " <> userColumns )
          (uid, email, pwHash, displayName, explicitAdmin, firstUserFallback)
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
      ( "SELECT " <> userColumns <> " FROM users WHERE email = ?" )
      (Only email)
  pure (listToMaybe' rows)

-- | 사용자가 관리자인지만 확인한다(권한 검사 전용, 행 전체를 끌어오지 않음).
--   사용자가 없으면 @False@.
userIsAdmin :: Pool Connection -> UUID -> IO Bool
userIsAdmin pool uid = withConn pool $ \c -> do
  rows <- query c "SELECT is_admin FROM users WHERE id = ?" (Only uid)
  pure (maybe False fromOnly (listToMaybe' rows))

-- | ID로 사용자를 조회한다.
getUserById :: Pool Connection -> UUID -> IO (Maybe UserRow)
getUserById pool uid = withConn pool $ \c -> do
  rows <-
    query
      c
      ( "SELECT " <> userColumns <> " FROM users WHERE id = ?" )
      (Only uid)
  pure (listToMaybe' rows)

-- | 프로필 필드를 갱신하고 갱신된 행을 돌려준다.
updateProfile
  :: Pool Connection -> UUID -> Text -> Text -> Text -> Text -> IO (Maybe UserRow)
updateProfile pool uid displayName bio timezone themeKey = withConn pool $ \c -> do
  rows <-
    query
      c
      ( "UPDATE users SET display_name = ?, bio = ?, timezone = ?, theme_key = ?\
        \ WHERE id = ?\
        \ RETURNING " <> userColumns )
      (displayName, bio, timezone, themeKey, uid)
  pure (listToMaybe' rows)

-- | ADMIN_EMAILS 로 지정된 이메일들을 관리자로 승격한다 (기동 시 호출, 멱등).
--   이미 가입한 소유자 계정도 확실히 관리자가 되도록 보장한다 (대소문자 무관).
promoteAdmins :: Pool Connection -> [Text] -> IO ()
promoteAdmins pool emails =
  unless (null emails) $
    withConn pool $ \c -> do
      _ <-
        execute
          c
          "UPDATE users SET is_admin = true WHERE lower(email) IN ?"
          (Only (In emails))
      pure ()

-- | 안전한 head.
listToMaybe' :: [a] -> Maybe a
listToMaybe' []      = Nothing
listToMaybe' (x : _) = Just x
