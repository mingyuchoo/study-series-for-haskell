-- | PostgreSQL 연결 풀과 'PostStore'/'UserStore' 구현(어댑터).
--
-- 도메인 타입('Blog.Post'/'Blog.User')은 postgresql-simple에 의존하지 않는다.
-- DB 행 ↔ 도메인 변환은 이 모듈이 'toPost'/'toUser'로 명시적으로 책임진다.
module Blog.Database
  ( DbPool
  , newDbPool
  , runMigrations
  , postgresStore
  , postgresUserStore
  , postgresVerificationStore
  ) where

import Control.Exception (Exception, catch, throwIO)
import Data.ByteString (ByteString)
import Data.Maybe (listToMaybe)
import Data.Pool (Pool, defaultPoolConfig, newPool, withResource)
import Data.Text (Text)
import Data.Time (UTCTime)
import Database.PostgreSQL.Simple
import Database.PostgreSQL.Simple.ToField (ToField)

import Blog.Post (NewPost (..), Post (..), PostStore (..), PostView (..))
import Blog.User
  ( NewUser (..)
  , Theme
  , User (..)
  , UserError (..)
  , UserStore (..)
  , parseTheme
  , renderTheme
  )
import Blog.Verification (PendingSignup (..), VerificationStore (..))

-- | PostgreSQL 연결 풀.
type DbPool = Pool Connection

-- | DB 불변식 위반을 나타내는 예외.
--
-- 도메인 에러('UserError' 의 'EmailTaken' 같은 정상적 실패)는 'Either' 로
-- 표현하고, "있을 수 없는" 상황(@INSERT ... RETURNING@ 이 행을 안 돌려줌 등)은
-- 이 예외로 던진다. 두 저장소가 같은 규약을 따른다.
newtype DbError = DbError String
  deriving stock (Show)

instance Exception DbError

-- | @INSERT ... RETURNING@ 이 반드시 한 행을 돌려준다는 불변식을 강제한다.
--   비어 있으면 도메인 에러가 아니라 'DbError' 예외다.
firstRow :: String -> (r -> a) -> [r] -> IO a
firstRow _ f (r : _) = pure (f r)
firstRow what _ []   = throwIO (DbError (what <> ": RETURNING이 행을 반환하지 않았습니다"))

-- | 연결 문자열로부터 풀을 생성한다.
--
-- 유휴 타임아웃 60초, 최대 10개 연결.
newDbPool :: ByteString -> IO DbPool
newDbPool connStr =
  newPool (defaultPoolConfig (connectPostgreSQL connStr) close 60 10)

-- | 테이블이 없으면 생성한다 (애플리케이션 시작 시 1회).
--
-- users 를 먼저 만들어 posts.author_id 외래키 대상을 보장한다.
runMigrations :: DbPool -> IO ()
runMigrations pool = withResource pool $ \conn -> do
  _ <- execute_ conn usersMigration
  _ <- execute_ conn usersBioUpgrade
  _ <- execute_ conn usersThemeUpgrade
  _ <- execute_ conn postsMigration
  _ <- execute_ conn postsAuthorUpgrade
  _ <- execute_ conn verificationsMigration
  _ <- execute_ conn postsCreatedAtIndex
  _ <- execute_ conn postsAuthorIndex
  pure ()

usersMigration :: Query
usersMigration =
  "CREATE TABLE IF NOT EXISTS users \
  \( id SERIAL PRIMARY KEY \
  \, email TEXT NOT NULL UNIQUE \
  \, name TEXT NOT NULL \
  \, bio TEXT NOT NULL DEFAULT '' \
  \, password_hash TEXT NOT NULL \
  \, created_at TIMESTAMPTZ NOT NULL DEFAULT now() \
  \)"

-- | 1단계에서 만든 users 테이블에 bio 컬럼을 보강(기존 행은 빈 문자열).
usersBioUpgrade :: Query
usersBioUpgrade =
  "ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT NOT NULL DEFAULT ''"

-- | 계정별 테마 컬럼을 보강(기존 행은 라이트).
usersThemeUpgrade :: Query
usersThemeUpgrade =
  "ALTER TABLE users ADD COLUMN IF NOT EXISTS theme TEXT NOT NULL DEFAULT 'light'"

-- | 가입 인증 대기 테이블. 이메일이 PK 라 재요청·재전송 시 같은 행을 교체한다.
verificationsMigration :: Query
verificationsMigration =
  "CREATE TABLE IF NOT EXISTS email_verifications \
  \( email TEXT PRIMARY KEY \
  \, name TEXT NOT NULL \
  \, password_hash TEXT NOT NULL \
  \, code_hash TEXT NOT NULL \
  \, expires_at TIMESTAMPTZ NOT NULL \
  \, attempts INTEGER NOT NULL DEFAULT 0 \
  \)"

postsMigration :: Query
postsMigration =
  "CREATE TABLE IF NOT EXISTS posts \
  \( id SERIAL PRIMARY KEY \
  \, title TEXT NOT NULL \
  \, body TEXT NOT NULL \
  \, author_id INTEGER NOT NULL REFERENCES users(id) \
  \, created_at TIMESTAMPTZ NOT NULL DEFAULT now() \
  \)"

-- | author_id 가 없는 구(舊) posts 테이블을 업그레이드한다(1회).
--
-- 컬럼이 없을 때만 실행되므로 재시작마다 반복되지 않는다. 작성자 정보를 채울
-- 수 없는 기존 글은 비우고(2단계 결정: 기존 글 삭제) 컬럼을 추가한다.
-- | 홈 목록의 @ORDER BY created_at DESC@(+페이지네이션) 정렬을 인덱스로 받친다.
--   인덱스가 없으면 매 요청마다 posts 전체를 정렬한다.
postsCreatedAtIndex :: Query
postsCreatedAtIndex =
  "CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts (created_at DESC)"

-- | 작성자별 조회('listPostsByAuthor')와 작성자 JOIN 의 @author_id@ 탐색을 받친다.
postsAuthorIndex :: Query
postsAuthorIndex =
  "CREATE INDEX IF NOT EXISTS idx_posts_author_id ON posts (author_id)"

postsAuthorUpgrade :: Query
postsAuthorUpgrade =
  "DO $$ \
  \BEGIN \
  \  IF NOT EXISTS ( \
  \    SELECT 1 FROM information_schema.columns \
  \    WHERE table_name = 'posts' AND column_name = 'author_id' \
  \  ) THEN \
  \    TRUNCATE posts; \
  \    ALTER TABLE posts ADD COLUMN author_id INTEGER NOT NULL REFERENCES users(id); \
  \  END IF; \
  \END $$"

-- 글 저장소 ------------------------------------------------------------

-- | PostgreSQL 기반 'PostStore' 구현.
postgresStore :: DbPool -> PostStore
postgresStore pool =
  PostStore
    { storeList = listPosts pool
    , storeListByAuthor = listPostsByAuthor pool
    , storeGet = getPost pool
    , storeInsert = insertPost pool
    , storeUpdate = updatePost pool
    , storeDelete = deletePost pool
    }

-- | posts 행(저장용). 작성자 이름은 포함하지 않는다.
type PostRow = (Int, Text, Text, UTCTime, Int)

toPost :: PostRow -> Post
toPost (pid, title, body, createdAt, authorId) =
  Post pid title body createdAt authorId

-- | posts 행 + 작성자 이름(조회용 읽기 모델).
type PostViewRow = (Int, Text, Text, UTCTime, Int, Text)

toPostView :: PostViewRow -> PostView
toPostView (pid, title, body, createdAt, authorId, authorName) =
  PostView (Post pid title body createdAt authorId) authorName

-- | 조회용 컬럼(users JOIN 으로 작성자 이름을 함께 가져온다).
selectColumns :: Query
selectColumns = "p.id, p.title, p.body, p.created_at, p.author_id, u.name"

selectFrom :: Query
selectFrom = " FROM posts p JOIN users u ON u.id = p.author_id "

-- | INSERT/UPDATE 의 RETURNING 절(저장 행 컬럼만; 작성자 이름은 조회 시 JOIN).
returningColumns :: Query
returningColumns = "id, title, body, created_at, author_id"

listPosts :: DbPool -> Int -> Int -> IO [PostView]
listPosts pool limit offset = withResource pool $ \conn ->
  map toPostView
    <$> query
      conn
      ( "SELECT "
          <> selectColumns
          <> selectFrom
          <> "ORDER BY p.created_at DESC LIMIT ? OFFSET ?"
      )
      (limit, offset)

listPostsByAuthor :: DbPool -> Int -> IO [PostView]
listPostsByAuthor pool authorId = withResource pool $ \conn ->
  map toPostView
    <$> query
      conn
      ( "SELECT "
          <> selectColumns
          <> selectFrom
          <> "WHERE p.author_id = ? ORDER BY p.created_at DESC"
      )
      (Only authorId)

getPost :: DbPool -> Int -> IO (Maybe PostView)
getPost pool pid = withResource pool $ \conn -> do
  rows <-
    query
      conn
      ("SELECT " <> selectColumns <> selectFrom <> "WHERE p.id = ?")
      (Only pid)
  pure (firstPostView rows)

insertPost :: DbPool -> Int -> NewPost -> IO Post
insertPost pool authorId (NewPost title body) = withResource pool $ \conn -> do
  rows <-
    query
      conn
      ( "INSERT INTO posts (title, body, author_id) VALUES (?, ?, ?) RETURNING "
          <> returningColumns
      )
      (title, body, authorId)
  firstRow "INSERT posts" toPost rows

updatePost :: DbPool -> Int -> NewPost -> IO (Maybe Post)
updatePost pool pid (NewPost title body) = withResource pool $ \conn -> do
  rows <-
    query
      conn
      ("UPDATE posts SET title = ?, body = ? WHERE id = ? RETURNING " <> returningColumns)
      (title, body, pid)
  pure (firstPost rows)

deletePost :: DbPool -> Int -> IO Bool
deletePost pool pid = withResource pool $ \conn -> do
  n <- execute conn "DELETE FROM posts WHERE id = ?" (Only pid)
  pure (n > 0)

-- | 결과 행 목록의 첫 행을 변환한다(없으면 'Nothing').
firstPost :: [PostRow] -> Maybe Post
firstPost = fmap toPost . listToMaybe

firstPostView :: [PostViewRow] -> Maybe PostView
firstPostView = fmap toPostView . listToMaybe

-- 사용자 저장소 ----------------------------------------------------------

-- | PostgreSQL 기반 'UserStore' 구현.
postgresUserStore :: DbPool -> UserStore
postgresUserStore pool =
  UserStore
    { userInsert = insertUser pool
    , userByEmail = getUserBy pool "email"
    , userById = getUserBy pool "id"
    , userUpdateProfile = updateUserProfile pool
    , userUpdatePassword = updateUserPassword pool
    , userUpdateTheme = updateUserTheme pool
    }

-- | users 테이블의 한 행. 도메인 'User'와 분리해 둔다.
type UserRow = (Int, Text, Text, Text, Text, UTCTime, Text)

toUser :: UserRow -> User
toUser (uid, email, name, bio, hash, createdAt, theme) =
  User uid email name bio hash createdAt (parseTheme theme)

userColumns :: Query
userColumns = "id, email, name, bio, password_hash, created_at, theme"

insertUser :: DbPool -> NewUser -> IO (Either UserError User)
insertUser pool (NewUser email name hash) = withResource pool $ \conn ->
  insert conn `catch` onSqlError
  where
    insert conn = do
      rows <-
        query
          conn
          ( "INSERT INTO users (email, name, password_hash) VALUES (?, ?, ?) RETURNING "
              <> userColumns
          )
          (email, name, hash)
      Right <$> firstRow "INSERT users" toUser rows

    -- 23505 = unique_violation (이메일 중복).
    onSqlError :: SqlError -> IO (Either UserError User)
    onSqlError e
      | sqlState e == "23505" = pure (Left EmailTaken)
      | otherwise = throwIO e

-- | 단일 컬럼(email 또는 id) 동등 조건으로 사용자를 조회한다.
getUserBy :: (ToField a) => DbPool -> Query -> a -> IO (Maybe User)
getUserBy pool column val = withResource pool $ \conn -> do
  rows <-
    query
      conn
      ("SELECT " <> userColumns <> " FROM users WHERE " <> column <> " = ?")
      (Only val)
  pure (firstUser rows)

updateUserProfile :: DbPool -> Int -> Text -> Text -> IO (Maybe User)
updateUserProfile pool uid name bio = withResource pool $ \conn -> do
  rows <-
    query
      conn
      ("UPDATE users SET name = ?, bio = ? WHERE id = ? RETURNING " <> userColumns)
      (name, bio, uid)
  pure (firstUser rows)

updateUserPassword :: DbPool -> Int -> Text -> IO (Maybe User)
updateUserPassword pool uid hash = withResource pool $ \conn -> do
  rows <-
    query
      conn
      ("UPDATE users SET password_hash = ? WHERE id = ? RETURNING " <> userColumns)
      (hash, uid)
  pure (firstUser rows)

updateUserTheme :: DbPool -> Int -> Theme -> IO (Maybe User)
updateUserTheme pool uid theme = withResource pool $ \conn -> do
  rows <-
    query
      conn
      ("UPDATE users SET theme = ? WHERE id = ? RETURNING " <> userColumns)
      (renderTheme theme, uid)
  pure (firstUser rows)

firstUser :: [UserRow] -> Maybe User
firstUser = fmap toUser . listToMaybe

-- 가입 인증 저장소 ------------------------------------------------------

-- | PostgreSQL 기반 'VerificationStore' 구현.
postgresVerificationStore :: DbPool -> VerificationStore
postgresVerificationStore pool =
  VerificationStore
    { storePending = storePendingRow pool
    , getPending = getPendingRow pool
    , bumpAttempts = bumpAttemptsRow pool
    , deletePending = deletePendingRow pool
    }

type VerificationRow = (Text, Text, Text, Text, UTCTime, Int)

toPending :: VerificationRow -> PendingSignup
toPending (email, name, pwHash, codeHash, expiresAt, attempts) =
  PendingSignup email name pwHash codeHash expiresAt attempts

storePendingRow :: DbPool -> PendingSignup -> IO ()
storePendingRow pool (PendingSignup email name pwHash codeHash expiresAt _) =
  withResource pool $ \conn ->
    ()
      <$ execute
        conn
        "INSERT INTO email_verifications (email, name, password_hash, code_hash, expires_at, attempts) \
        \VALUES (?, ?, ?, ?, ?, 0) \
        \ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name, \
        \password_hash = EXCLUDED.password_hash, code_hash = EXCLUDED.code_hash, \
        \expires_at = EXCLUDED.expires_at, attempts = 0"
        (email, name, pwHash, codeHash, expiresAt)

getPendingRow :: DbPool -> Text -> IO (Maybe PendingSignup)
getPendingRow pool email = withResource pool $ \conn -> do
  rows <-
    query
      conn
      "SELECT email, name, password_hash, code_hash, expires_at, attempts \
      \FROM email_verifications WHERE email = ?"
      (Only email)
  pure (toPending <$> listToMaybe rows)

bumpAttemptsRow :: DbPool -> Text -> IO ()
bumpAttemptsRow pool email = withResource pool $ \conn ->
  ()
    <$ execute
      conn
      "UPDATE email_verifications SET attempts = attempts + 1 WHERE email = ?"
      (Only email)

deletePendingRow :: DbPool -> Text -> IO ()
deletePendingRow pool email = withResource pool $ \conn ->
  () <$ execute conn "DELETE FROM email_verifications WHERE email = ?" (Only email)
