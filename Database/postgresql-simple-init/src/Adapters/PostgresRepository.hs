module Adapters.PostgresRepository
  ( PostgresRepo (..)
  , initSchema
  , runWith
  , withPostgresRepo
  ) where

import Control.Exception (bracket)
import Control.Monad (void)

import Data.Maybe (listToMaybe)

import Database.PostgreSQL.Simple
import Database.PostgreSQL.Simple.FromRow
import Database.PostgreSQL.Simple.ToRow

import Domain.Model (User (..))
import Domain.Repository (UserRepository (..))

-- | 내부 전용: DB 행 매핑
instance FromRow User where
  fromRow = User <$> field <*> field

instance ToRow User where
  toRow (User uid uname) = toRow (uid, uname)

-- | 구체 구현을 담는 newtype 래퍼
newtype PostgresRepo a = PostgresRepo { runRepo :: Connection -> IO a }

-- | Functor 인스턴스
instance Functor PostgresRepo where
  fmap f (PostgresRepo g) = PostgresRepo $ \conn -> fmap f (g conn)

-- | Applicative 인스턴스
instance Applicative PostgresRepo where
  pure x = PostgresRepo $ \_ -> pure x
  (PostgresRepo f) <*> (PostgresRepo x) = PostgresRepo $ \conn -> f conn <*> x conn

-- | Monad 인스턴스
instance Monad PostgresRepo where
  (PostgresRepo m) >>= k = PostgresRepo $ \conn -> do
    a <- m conn
    runRepo (k a) conn

-- | typeclass 인스턴스: IO 모나드에서 동작
instance UserRepository (PostgresRepo) where
  createUser u = PostgresRepo $ \conn -> do
    n <-
      execute conn "INSERT INTO users (id, name) VALUES (?, ?) ON CONFLICT (id) DO NOTHING" u
    pure (n > 0)
  updateUser (User i n) = PostgresRepo $ \conn -> do
    n' <- execute conn "UPDATE users SET name = ? WHERE id = ?" (n, i)
    pure (n' > 0)
  retrieveUser i = PostgresRepo $ \conn -> do
    rows <- query conn "SELECT id, name FROM users WHERE id = ?" (Only i)
    pure (listToMaybe rows)
  deleteUser i = PostgresRepo $ \conn -> do
    n <- execute conn "DELETE FROM users WHERE id = ?" (Only i)
    pure (n > 0)
  listUsers = PostgresRepo $ \conn -> query_ conn "SELECT id, name FROM users ORDER BY id"

-- | 스키마 초기화
initSchema :: Connection -> IO ()
initSchema conn = do
  void $
    execute_ conn "CREATE TABLE IF NOT EXISTS users (id INT PRIMARY KEY, name TEXT NOT NULL)"

-- | 커넥션과 함께 실행 도우미
withPostgresRepo :: ConnectInfo -> (Connection -> IO a) -> IO a
withPostgresRepo ci action = bracket (connect ci) close action

-- | 주어진 커넥션으로 레포지토리 동작 실행
runWith :: Connection -> PostgresRepo a -> IO a
runWith conn repo = runRepo repo conn
