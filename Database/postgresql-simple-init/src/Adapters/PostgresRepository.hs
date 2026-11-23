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

instance FromRow User where
  fromRow = User <$> field <*> field

instance ToRow User where
  toRow (User uid uname) = toRow (uid, uname)

newtype PostgresRepo a = PostgresRepo { runRepo :: Connection -> IO a }

instance Functor PostgresRepo where
  fmap f (PostgresRepo g) = PostgresRepo $ \conn -> fmap f (g conn)

instance Applicative PostgresRepo where
  pure x = PostgresRepo $ \_ -> pure x
  (PostgresRepo f) <*> (PostgresRepo x) = PostgresRepo $ \conn -> f conn <*> x conn

instance Monad PostgresRepo where
  (PostgresRepo m) >>= k = PostgresRepo $ \conn -> do
    a <- m conn
    runRepo (k a) conn

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

initSchema :: Connection -> IO ()
initSchema conn = do
  void $
    execute_ conn "CREATE TABLE IF NOT EXISTS users (id INT PRIMARY KEY, name TEXT NOT NULL)"

withPostgresRepo :: ConnectInfo -> (Connection -> IO a) -> IO a
withPostgresRepo ci action = bracket (connect ci) close action

runWith :: Connection -> PostgresRepo a -> IO a
runWith conn repo = runRepo repo conn
