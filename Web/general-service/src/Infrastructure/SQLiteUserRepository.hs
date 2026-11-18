{-# LANGUAGE OverloadedStrings #-}

module Infrastructure.SQLiteUserRepository
  ( newSQLiteUserRepository
  )
where

import Application.Port.UserRepository (UserRepository (..))
import Database.SQLite.Simple
  ( FromRow (..)
  , Only (..)
  , execute
  , field
  , lastInsertRowId
  , query
  )
import Domain.User (ProfileUpdate (..), User (..))
import Infrastructure.SQLiteDatabase
  ( SQLiteDatabase
  , withSQLiteConnection
  )

newtype UserRow = UserRow {fromUserRow :: User}

instance FromRow UserRow where
  fromRow = UserRow <$> (User <$> field <*> field <*> field <*> field)

newSQLiteUserRepository :: SQLiteDatabase -> IO (UserRepository IO)
newSQLiteUserRepository database =
  pure
    UserRepository
      { findUserByEmail = \email ->
          withSQLiteConnection database $ \connection -> do
            users <-
              query
                connection
                "SELECT id, email, display_name, password_hash FROM users WHERE email = ?"
                (Only email)
            pure (fromUserRow <$> firstOrNothing users)
      , createStoredUser = \email displayName passwordHash ->
          withSQLiteConnection database $ \connection -> do
            execute
              connection
              "INSERT INTO users (email, display_name, password_hash) VALUES (?, ?, ?)"
              (email, displayName, passwordHash)
            identifier <- fromIntegral <$> lastInsertRowId connection
            pure (User identifier email displayName passwordHash)
      , findUserById = \identifier ->
          withSQLiteConnection database $ \connection -> do
            users <-
              query
                connection
                "SELECT id, email, display_name, password_hash FROM users WHERE id = ?"
                (Only identifier)
            pure (fromUserRow <$> firstOrNothing users)
      , updateStoredProfile = \identifier (ProfileUpdate displayName) ->
          withSQLiteConnection database $ \connection -> do
            execute
              connection
              "UPDATE users SET display_name = ? WHERE id = ?"
              (displayName, identifier)
            users <-
              query
                connection
                "SELECT id, email, display_name, password_hash FROM users WHERE id = ?"
                (Only identifier)
            pure (fromUserRow <$> firstOrNothing users)
      , createStoredSession = \identifier token ->
          withSQLiteConnection database $ \connection ->
            execute
              connection
              "INSERT INTO sessions (token, user_id, expires_at) VALUES (?, ?, datetime('now', '+24 hours')) ON CONFLICT(token) DO UPDATE SET user_id = excluded.user_id, expires_at = excluded.expires_at"
              (token, identifier)
      , findUserBySession = \token ->
          withSQLiteConnection database $ \connection -> do
            execute
              connection
              "DELETE FROM sessions WHERE token = ? AND expires_at <= CURRENT_TIMESTAMP"
              (Only token)
            users <-
              query
                connection
                "SELECT users.id, users.email, users.display_name, users.password_hash FROM sessions INNER JOIN users ON users.id = sessions.user_id WHERE sessions.token = ? AND sessions.expires_at > CURRENT_TIMESTAMP"
                (Only token)
            pure (fromUserRow <$> firstOrNothing users)
      , deleteStoredSession = \token ->
          withSQLiteConnection database $ \connection ->
            execute connection "DELETE FROM sessions WHERE token = ?" (Only token)
      }

firstOrNothing :: [a] -> Maybe a
firstOrNothing [] = Nothing
firstOrNothing (value : _) = Just value
