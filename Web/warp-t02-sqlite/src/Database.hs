{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}

module Database
  ( User (..)
  , createUser
  , deleteUser
  , getUser
  , getUsers
  , initDB
  , updateUser
  ) where

import Data.Aeson
  ( FromJSON
  , ToJSON
  , object
  , parseJSON
  , toJSON
  , withObject
  , (.!=)
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.Text qualified as T

import Database.SQLite.Simple

import Flow ((<|))

-- | Database initialization
initDB :: IO Connection
initDB = do
  conn <- open "users.db"
  execute_
    conn
    "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)"
  return conn

-- | User data type
data User = User
  { userId   :: Maybe Int
  , userName :: T.Text
  }
  deriving (Show)

-- | User data type
instance FromRow User where
  fromRow = User <$> field <*> field

-- | User data type
instance ToRow User where
  toRow (User Nothing name)    = toRow (Only name)
  toRow (User (Just id') name) = toRow (id', name)

-- | User data type
instance ToJSON User where
  toJSON (User id' name) =
    object
      [ "id" .= id'
      , "name" .= name
      ]

-- | User data type
instance FromJSON User where
  parseJSON =
    withObject "User" <| \v ->
      User
        <$> v .:? "id" .!= Nothing
        <*> v .: "name"

-- | Create a new user
createUser :: Connection -> User -> IO User
createUser conn user = do
  execute conn "INSERT INTO users (name) VALUES (?)" (Only (userName user))
  rowId <- lastInsertRowId conn
  let userId' = Just (fromIntegral rowId)
  return <| user {userId = userId'}

-- | Get a user by ID
getUser :: Connection -> Int -> IO (Maybe User)
getUser conn userId' = do
  results <- query conn "SELECT id, name FROM users WHERE id = ?" (Only userId')
  case results of
    [user] -> return <| Just user
    _      -> return Nothing

-- | Get all users
getUsers :: Connection -> IO [User]
getUsers conn = query_ conn "SELECT id, name FROM users"

-- | Update a user
updateUser :: Connection -> User -> IO Bool
updateUser conn User {..} = case userId of
  Just id' -> do
    execute conn "UPDATE users SET name = ? WHERE id = ?" (userName, id')
    rows <- query conn "SELECT changes()" () :: IO [Only Int]
    case rows of
      [Only n] -> return <| n > 0
      _        -> return False
  Nothing -> return False

-- | Delete a user
deleteUser :: Connection -> Int -> IO Bool
deleteUser conn userId' = do
  execute conn "DELETE FROM users WHERE id = ?" (Only userId')
  rows <- query conn "SELECT changes()" () :: IO [Only Int]
  case rows of
    [Only n] -> return <| n > 0
    _        -> return False
