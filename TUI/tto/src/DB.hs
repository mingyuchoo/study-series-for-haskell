{-# LANGUAGE OverloadedStrings #-}

-- | Database operations (Effectful)
--
-- This module handles all SQLite database interactions.
-- All functions perform IO operations.
--
-- Effects:
--   - SQLite database queries and updates
--   - Current time retrieval (getCurrentTime)
--
-- Purity: NONE - All exported functions are effectful
module DB
    ( TodoId
    , TodoRow (..)
    , createTodo
    , createTodoWithFields
    , deleteTodo
    , getAllTodos
    , initDB
    , initDBWithMessages
    , transitionToCancelled
    , transitionToCompleted
    , transitionToInProgress
    , transitionToRegistered
    , updateTodo
    , updateTodoWithFields
    ) where

import           Data.Time.Clock        (getCurrentTime)
import           Data.Time.Format       (defaultTimeLocale, formatTime)

import           Database.SQLite.Simple (Connection, FromRow (..), Only (..),
                                         ToRow (..), execute, execute_, field,
                                         lastInsertRowId, query_)

import qualified I18n

import qualified TodoStatus

type TodoId = Int

-- | Domain model for a Todo item (Effectful)
data TodoRow = TodoRow { todoId              :: !TodoId
                       , todoAction          :: !String
                       , todoStatus          :: !String
                       , todoCreatedAt       :: !String
                       , todoSubject         :: !(Maybe String)
                       , todoIndirectObject  :: !(Maybe String)
                       , todoDirectObject    :: !(Maybe String)
                       , todoStatusChangedAt :: !(Maybe String)
                       }
     deriving (Eq, Show)

instance FromRow TodoRow where
    fromRow = TodoRow
        <$> field <*> field <*> field <*> field
        <*> field <*> field <*> field <*> field

instance ToRow TodoRow where
    toRow (TodoRow tid txt status created subj indObj dirObj statusChangedAt) =
        toRow (tid, txt, status, created, subj, indObj, dirObj, statusChangedAt)

-- | Initialize database schema and seed data (Effectful)
initDB :: Connection -> IO ()
initDB conn = initDBWithMessages conn I18n.defaultMessages

-- | Initialize database with custom messages (Effectful)
initDBWithMessages :: Connection -> I18n.I18nMessages -> IO ()
initDBWithMessages conn msgs = do
    createTodosTable
    seedInitialData
  where
    createTodosTable = execute_ conn
        "CREATE TABLE IF NOT EXISTS todos \
        \(id INTEGER PRIMARY KEY AUTOINCREMENT, \
        \ text TEXT NOT NULL, \
        \ status TEXT NOT NULL DEFAULT 'registered', \
        \ created_at TEXT NOT NULL, \
        \ subject TEXT, \
        \ object TEXT, \
        \ indirect_object TEXT, \
        \ direct_object TEXT, \
        \ status_changed_at TEXT)"

    seedInitialData = do
        count <- query_ conn "SELECT COUNT(*) FROM todos" :: IO [Only Int]
        case count of
            [Only 0] -> insertSampleTodos
            _        -> pure ()

    insertSampleTodos = do
        timestamp <- getCurrentTime
        let timeStr = formatTime defaultTimeLocale "%Y-%m-%d %H:%M" timestamp
            insertTodo txt status = execute conn
                "INSERT INTO todos (text, status, created_at, subject, \
                \indirect_object, direct_object, status_changed_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
                (txt :: String, status :: String, timeStr,
                 Nothing :: Maybe String,
                 Nothing :: Maybe String, Nothing :: Maybe String,
                 if status == "completed" then Just timeStr else Nothing :: Maybe String)
            samples = I18n.sample_todos msgs

        insertTodo (I18n.welcome samples) "registered"
        insertTodo (I18n.add_hint samples) "in_progress"
        insertTodo (I18n.toggle_hint samples) "completed"

-- | Create a new todo with action text only (Effectful)
createTodo :: Connection -> String -> IO TodoId
createTodo conn text = do
    timeStr <- formatCurrentTime
    let status = TodoStatus.statusToString TodoStatus.registered
    execute conn
        "INSERT INTO todos (text, status, created_at, subject, \
        \indirect_object, direct_object, status_changed_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
        (text, status, timeStr,
         Nothing :: Maybe String,
         Nothing :: Maybe String, Nothing :: Maybe String,
         Nothing :: Maybe String)
    fromIntegral <$> lastInsertRowId conn

-- | Create a new todo with all fields (Effectful)
createTodoWithFields :: Connection -> String -> Maybe String -> Maybe String -> Maybe String -> IO TodoId
createTodoWithFields conn text subj indObj dirObj = do
    timeStr <- formatCurrentTime
    let status = TodoStatus.statusToString TodoStatus.registered
    execute conn
        "INSERT INTO todos (text, status, created_at, subject, \
        \indirect_object, direct_object, status_changed_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
        (text, status, timeStr, subj, indObj, dirObj,
         Nothing :: Maybe String)
    fromIntegral <$> lastInsertRowId conn

-- | Retrieve all todos ordered by ID descending (Effectful)
getAllTodos :: Connection -> IO [TodoRow]
getAllTodos conn = query_ conn
    "SELECT id, text, status, created_at, subject, \
    \indirect_object, direct_object, status_changed_at \
    \FROM todos ORDER BY id DESC"

-- | Update all fields of a todo (Effectful)
updateTodo :: Connection -> TodoId -> String -> String -> Maybe String -> Maybe String -> Maybe String -> Maybe String -> IO ()
updateTodo conn tid text status subj indObj dirObj statusChangedAt =
    execute conn
        "UPDATE todos SET text = ?, status = ?, subject = ?, \
        \indirect_object = ?, direct_object = ?, status_changed_at = ? WHERE id = ?"
        (text, status, subj, indObj, dirObj, statusChangedAt, tid)

-- | Update specific fields of a todo (Effectful)
updateTodoWithFields :: Connection -> TodoId -> String -> Maybe String -> Maybe String -> Maybe String -> IO ()
updateTodoWithFields conn tid text subj indObj dirObj =
    execute conn
        "UPDATE todos SET text = ?, subject = ?, indirect_object = ?, \
        \direct_object = ? WHERE id = ?"
        (text, subj, indObj, dirObj, tid)

-- | Delete a todo by ID (Effectful)
deleteTodo :: Connection -> TodoId -> IO ()
deleteTodo conn tid = execute conn "DELETE FROM todos WHERE id = ?" (Only tid)

-- | Transition todo from Registered to InProgress (Effectful)
transitionToInProgress :: Connection -> TodoId -> IO ()
transitionToInProgress conn tid = do
    timeStr <- formatCurrentTime
    execute conn
        "UPDATE todos SET status = ?, status_changed_at = ? WHERE id = ? AND status = ?"
        (TodoStatus.statusToString TodoStatus.StatusInProgress, timeStr, tid,
         TodoStatus.statusToString TodoStatus.registered)

-- | Transition todo from InProgress to Cancelled (Effectful)
transitionToCancelled :: Connection -> TodoId -> IO ()
transitionToCancelled conn tid = do
    timeStr <- formatCurrentTime
    execute conn
        "UPDATE todos SET status = ?, status_changed_at = ? WHERE id = ? AND status = ?"
        (TodoStatus.statusToString TodoStatus.StatusCancelled, timeStr, tid,
         TodoStatus.statusToString TodoStatus.StatusInProgress)

-- | Transition todo from Cancelled to Completed (Effectful)
transitionToCompleted :: Connection -> TodoId -> IO ()
transitionToCompleted conn tid = do
    timeStr <- formatCurrentTime
    execute conn
        "UPDATE todos SET status = ?, status_changed_at = ? WHERE id = ? AND status = ?"
        (TodoStatus.statusToString TodoStatus.StatusCompleted, timeStr, tid,
         TodoStatus.statusToString TodoStatus.StatusCancelled)

-- | Transition todo from Completed to Registered (Effectful)
transitionToRegistered :: Connection -> TodoId -> IO ()
transitionToRegistered conn tid = do
    timeStr <- formatCurrentTime
    execute conn
        "UPDATE todos SET status = ?, status_changed_at = ? WHERE id = ? AND status = ?"
        (TodoStatus.statusToString TodoStatus.registered, timeStr, tid,
         TodoStatus.statusToString TodoStatus.StatusCompleted)

-- | Helper function to format current time (Effectful)
formatCurrentTime :: IO String
formatCurrentTime = formatTime defaultTimeLocale "%Y-%m-%d %H:%M" <$> getCurrentTime
