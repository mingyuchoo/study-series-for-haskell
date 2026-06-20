{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE RecordWildCards            #-}

-- | SQLite implementation of the Todo repository
module Infrastructure.Repositories.SQLiteTodoRepository
  ( -- * Repository implementation
    SQLiteRepo (..)
    -- * Database operations
  , migrate
  , withConn
    -- * Direct access functions
    -- | These functions are exported for direct use in tests or specialized scenarios
  , deleteTodoById
  , insertTodo
  , selectAllTodos
  , selectTodoById
  , updateTodoById
  ) where

-- -------------------------------------------------------------------
-- Imports
-- -------------------------------------------------------------------

import Control.Exception (try)
import Control.Monad (void)

import Data.Text qualified as T
import Data.Time (getCurrentTime)

import Database.SQLite.Simple
  ( Connection
  , Only (Only)
  , close
  , execute
  , execute_
  , lastInsertRowId
  , open
  , query
  , query_
  )

import Domain.Repositories.Entities.Todo (validateTodoTitle)
import Domain.Repositories.TodoRepository
  ( NewTodo (newTodoTitle)
  , Todo (Todo, priority, status, todoTitle)
  , TodoRepository (..)
  , ValidationError (..)
  )

import Flow ((<|))

-- -------------------------------------------------------------------
-- Infrastructure
-- -------------------------------------------------------------------

-- | Newtype wrapper for SQLite IO operations
newtype SQLiteRepo a = SQLiteRepo { runSQLiteRepo :: IO a }
  deriving (Applicative, Functor, Monad)

-- | TodoRepository implementation for SQLiteRepo
instance TodoRepository SQLiteRepo where
  getAllTodos = SQLiteRepo selectAllTodos
  getTodoById = SQLiteRepo . selectTodoById
  createTodo = SQLiteRepo . insertTodo
  updateTodo tid = SQLiteRepo . updateTodoById tid
  deleteTodo = SQLiteRepo . deleteTodoById

-- | Database connection helper
-- Opens a connection, runs the action, and ensures the connection is closed
withConn :: (Connection -> IO a) -> IO a
withConn action = do
  conn <- open "haskell_todo.db"
  result <- action conn
  close conn
  pure result

-- | Initialize the database schema
-- This will recreate the table if it already exists
migrate :: IO ()
migrate =
  withConn <| \conn -> do
    -- Drop the existing table if it exists (for schema migration)
    execute_ conn "DROP TABLE IF EXISTS haskell_todo"
    -- Create the table with the new schema
    execute_
      conn
      "CREATE TABLE IF NOT EXISTS haskell_todo (todoId INTEGER PRIMARY KEY AUTOINCREMENT, todoTitle TEXT NOT NULL, createdAt TEXT NOT NULL, priority TEXT NOT NULL, status TEXT NOT NULL)"

-- | Direct functions for database operations

-- | Get all todos from the database
selectAllTodos :: IO [Todo]
selectAllTodos =
  withConn <| \conn ->
    query_ conn "SELECT todoId, todoTitle, createdAt, priority, status FROM haskell_todo"

-- | Get a specific todo by ID
-- Returns an empty list if the todo doesn't exist
selectTodoById :: Int -> IO [Todo]
selectTodoById todoId =
  withConn <| \conn ->
    query
      conn
      "SELECT todoId, todoTitle, createdAt, priority, status FROM haskell_todo WHERE todoId = ?"
      (Only todoId)

-- | Insert a new todo
-- Validates the todo title before insertion
insertTodo :: NewTodo -> IO (Either ValidationError [Todo])
insertTodo newTodo =
  case validateTodoTitle (newTodoTitle newTodo) of
    Left err -> pure <| Left err
    Right () -> do
      result <- try (insertTodoInDb newTodo) :: IO (Either IOError [Todo])
      case result of
        Left e -> pure <| Left <| ValidationError <| "Database error: " <> T.pack (show e)
        Right todos -> pure <| Right todos
  where
    insertTodoInDb :: NewTodo -> IO [Todo]
    insertTodoInDb todo =
      withConn <| \conn -> do
        currentTime <- getCurrentTime
        -- Use Medium as the default priority and TodoStatus as the default status
        execute
          conn
          "INSERT INTO haskell_todo (todoTitle, createdAt, priority, status) VALUES (?, ?, ?, ?)"
          (newTodoTitle todo, currentTime, ("Medium" :: String), ("Todo" :: String))
        rowId <- lastInsertRowId conn
        query
          conn
          "SELECT todoId, todoTitle, createdAt, priority, status FROM haskell_todo WHERE todoId = ?"
          (Only rowId)

-- | Update an existing todo
-- Validates the todo title before updating
updateTodoById :: Int -> Todo -> IO (Either ValidationError [Todo])
updateTodoById todoId' todo =
  case validateTodoTitle (todoTitle todo) of
    Left err -> pure <| Left err
    Right () -> do
      result <- try (updateTodoInDb todoId' todo) :: IO (Either IOError [Todo])
      case result of
        Left e -> pure <| Left <| ValidationError <| "Database error: " <> T.pack (show e)
        Right todos -> pure <| Right todos
  where
    updateTodoInDb :: Int -> Todo -> IO [Todo]
    updateTodoInDb tid Todo {..} =
      withConn <| \conn -> do
        -- Convert Priority to string
        let priorityStr = show priority
        -- Convert Status to string
        let statusStr = show status

        void <|
          execute
            conn
            "UPDATE haskell_todo SET todoTitle = ?, priority = ?, status = ? WHERE todoId = ?"
            (todoTitle, priorityStr, statusStr, tid)

        query
          conn
          "SELECT todoId, todoTitle, createdAt, priority, status FROM haskell_todo WHERE todoId = ?"
          (Only tid)

-- | Delete a todo by ID
-- Returns the deleted todo before removal
deleteTodoById :: Int -> IO [Todo]
deleteTodoById todoId =
  withConn <| \conn -> do
    -- First get the todo to return it
    todo <-
      query
        conn
        "SELECT todoId, todoTitle, createdAt, priority, status FROM haskell_todo WHERE todoId = ?"
        (Only todoId)

    -- Then delete it
    void <| execute conn "DELETE FROM haskell_todo WHERE todoId = ?" (Only todoId)

    -- Return the deleted todo
    pure todo
