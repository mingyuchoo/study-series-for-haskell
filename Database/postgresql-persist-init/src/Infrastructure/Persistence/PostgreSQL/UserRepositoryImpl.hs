{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE DerivingStrategies         #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GADTs                      #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE QuasiQuotes                #-}
{-# LANGUAGE RecordWildCards            #-}
{-# LANGUAGE StandaloneDeriving         #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE UndecidableInstances       #-}

module Infrastructure.Persistence.PostgreSQL.UserRepositoryImpl
    ( PGInfo
    , PostgreSQLUserRepository (..)
    , localConnString
    , migrateAll
    , migrateDB
    , runPostgreSQLUserRepository
    ) where

import           Control.Monad.IO.Class             (MonadIO, liftIO)
import           Control.Monad.Logger               (LogLevel (..), LoggingT,
                                                     filterLogger,
                                                     runStdoutLoggingT)
import           Control.Monad.Reader               (ReaderT, ask, runReaderT)

import           Data.Int                           (Int64)
import           Data.Text                          (Text)

import           Database.Persist
import           Database.Persist.Postgresql
import qualified Database.Persist.TH                as PTH

import           Domain.Entities.User
import           Domain.Repositories.UserRepository

-- Define the database schema
PTH.share
  [PTH.mkPersist PTH.sqlSettings, PTH.mkMigrate "migrateAll"]
  [PTH.persistLowerCase|
  DBUser sql=users
    name Text
    email Text
    age Int
    occupation Text
    UniqueEmail email
    deriving Show Read Eq
|]

-- Infrastructure types
type PGInfo = ConnectionString

localConnString :: PGInfo
localConnString = "host=127.0.0.1 port=5432 user=postgres dbname=postgres password=postgres"

-- Database operations
runAction :: PGInfo -> SqlPersistT (LoggingT IO) a -> IO a
runAction connectionString action =
  runStdoutLoggingT $ filterLogger logFilter $ withPostgresqlConn connectionString $ \backend ->
    runReaderT action backend

logFilter :: a -> LogLevel -> Bool
logFilter _ LevelError     = True
logFilter _ LevelWarn      = True
logFilter _ LevelInfo      = True
logFilter _ LevelDebug     = False
logFilter _ (LevelOther _) = False

migrateDB :: PGInfo -> IO ()
migrateDB connString = runAction connString (runMigration migrateAll)

-- Repository implementation monad
newtype PostgreSQLUserRepository a = PostgreSQLUserRepository (ReaderT PGInfo IO a)
     deriving (Applicative, Functor, Monad, MonadIO)

-- Run the repository
runPostgreSQLUserRepository :: PGInfo -> PostgreSQLUserRepository a -> IO a
runPostgreSQLUserRepository pgInfo (PostgreSQLUserRepository action) = runReaderT action pgInfo

-- Domain to DB conversion
domainUserToDB :: User -> DBUser
domainUserToDB (User _ (UserName name) (UserEmail email) (UserAge age) (UserOccupation occupation)) =
  DBUser name email age occupation

-- DB to Domain conversion
dbUserToDomain :: Int64 -> DBUser -> User
dbUserToDomain uid dbUser =
  User
    { userId = Just (UserId uid)
    , userName = UserName (dBUserName dbUser)
    , userEmail = UserEmail (dBUserEmail dbUser)
    , userAge = UserAge (dBUserAge dbUser)
    , userOccupation = UserOccupation (dBUserOccupation dbUser)
    }

-- Entity to Domain conversion
entityToDomain :: Entity DBUser -> User
entityToDomain (Entity key dbUser) = dbUserToDomain (fromSqlKey key) dbUser

-- Repository implementation
instance UserRepository PostgreSQLUserRepository where
  findUserById (UserId uid) = PostgreSQLUserRepository $ do
    pgInfo <- ask
    maybeUser <- liftIO $ runAction pgInfo (get (toSqlKey uid))
    return $ fmap (dbUserToDomain uid) maybeUser

  findAllUsers = PostgreSQLUserRepository $ do
    pgInfo <- ask
    entities <- liftIO $ runAction pgInfo (selectList [] [])
    return $ map entityToDomain entities

  saveUser user = PostgreSQLUserRepository $ do
    pgInfo <- ask
    uid <- liftIO $ runAction pgInfo (insert (domainUserToDB user))
    return $ UserId (fromSqlKey uid)

  updateUser (UserId uid) user = PostgreSQLUserRepository $ do
    pgInfo <- ask
    liftIO $ runAction pgInfo (replace (toSqlKey uid) (domainUserToDB user))
    return True

  deleteUser (UserId uid) = PostgreSQLUserRepository $ do
    pgInfo <- ask
    liftIO $ runAction pgInfo (delete (toSqlKey uid :: Key DBUser))
    return True

  findUserByEmail (UserEmail email) = PostgreSQLUserRepository $ do
    pgInfo <- ask
    entities <- liftIO $ runAction pgInfo (selectList [DBUserEmail ==. email] [])
    return $ case entities of
      []           -> Nothing
      (entity : _) -> Just $ entityToDomain entity
