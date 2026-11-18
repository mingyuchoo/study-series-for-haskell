{-# LANGUAGE OverloadedStrings #-}

module Infrastructure.SQLiteDatabase
  ( SQLiteDatabase
  , openSQLiteDatabase
  , closeSQLiteDatabase
  , withSQLiteConnection
  )
where

import Control.Concurrent.MVar (MVar, newMVar, withMVar)
import Control.Exception (onException)
import Control.Monad (forM_, unless, when)
import Database.SQLite.Simple
  ( Connection
  , Only (..)
  , close
  , execute
  , execute_
  , open
  , query_
  , withTransaction
  )

newtype SQLiteDatabase = SQLiteDatabase (MVar Connection)

openSQLiteDatabase :: FilePath -> IO SQLiteDatabase
openSQLiteDatabase path = do
  when (null path) (fail "database path must not be empty")
  connection <- open path
  (configure connection >> migrate connection) `onException` close connection
  SQLiteDatabase <$> newMVar connection

closeSQLiteDatabase :: SQLiteDatabase -> IO ()
closeSQLiteDatabase database = withSQLiteConnection database close

withSQLiteConnection :: SQLiteDatabase -> (Connection -> IO a) -> IO a
withSQLiteConnection (SQLiteDatabase connection) = withMVar connection

configure :: Connection -> IO ()
configure connection = do
  execute_ connection "PRAGMA foreign_keys = ON"
  execute_ connection "PRAGMA busy_timeout = 5000"
  _ <- query_ connection "PRAGMA journal_mode = WAL" :: IO [Only String]
  execute_ connection "PRAGMA synchronous = NORMAL"

migrate :: Connection -> IO ()
migrate connection = do
  withTransaction connection $
    execute_
      connection
      "CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)"
  appliedRows <-
    query_ connection "SELECT version FROM schema_migrations ORDER BY version"
      :: IO [Only Int]
  let applied = map fromOnly appliedRows
      supportedVersion = maximum (map fst migrations)
  when (any (> supportedVersion) applied) $
    fail
      ( "database schema version is newer than this server supports (supported: "
          <> show supportedVersion
          <> ")"
      )
  forM_ migrations $ \(version, action) ->
    unless (version `elem` applied) $
      withTransaction connection $ do
        action connection
        execute connection "INSERT INTO schema_migrations (version) VALUES (?)" (Only version)

migrations :: [(Int, Connection -> IO ())]
migrations =
  [
    ( 1
    , \connection -> do
        execute_
          connection
          "CREATE TABLE tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, description TEXT NOT NULL, status TEXT NOT NULL CHECK (status IN ('Draft', 'Reviewed', 'Submitted', 'Approved', 'Effective')), urgency TEXT NOT NULL CHECK (urgency IN ('Urgent', 'NotUrgent')), importance TEXT NOT NULL CHECK (importance IN ('Important', 'NotImportant')), task_owner TEXT NOT NULL, outcome_owner TEXT NOT NULL, expected_result TEXT NOT NULL, submitted_result TEXT, review_comment TEXT)"
        execute_
          connection
          "CREATE TABLE outcomes (id INTEGER PRIMARY KEY AUTOINCREMENT, description TEXT NOT NULL, outcome_owner TEXT NOT NULL, status TEXT NOT NULL CHECK (status = 'Effective'))"
        execute_
          connection
          "CREATE TABLE outcome_task_ids (outcome_id INTEGER NOT NULL REFERENCES outcomes(id) ON DELETE CASCADE, position INTEGER NOT NULL, task_id INTEGER NOT NULL, PRIMARY KEY (outcome_id, position))"
        execute_
          connection
          "CREATE TABLE outcome_results (outcome_id INTEGER NOT NULL REFERENCES outcomes(id) ON DELETE CASCADE, position INTEGER NOT NULL, result TEXT NOT NULL, PRIMARY KEY (outcome_id, position))"
        execute_
          connection
          "CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT NOT NULL UNIQUE, display_name TEXT NOT NULL, password_hash TEXT NOT NULL)"
        execute_
          connection
          "CREATE TABLE sessions (token TEXT PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, expires_at TEXT NOT NULL)"
        execute_
          connection
          "CREATE INDEX sessions_user_id_idx ON sessions(user_id)"
        execute_
          connection
          "CREATE TABLE app_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)"
    )
  ]
