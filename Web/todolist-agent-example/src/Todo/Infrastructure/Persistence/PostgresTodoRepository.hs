{-# LANGUAGE OverloadedStrings #-}

module Todo.Infrastructure.Persistence.PostgresTodoRepository (
    postgresTodoRepository,
) where

import Control.Exception (SomeException, bracket, try)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time (UTCTime)
import Database.PostgreSQL.Simple (
    Connection,
    Only (..),
    close,
    execute,
    query,
    query_,
 )
import Shared.Database (DatabaseConfig, connectDatabase)
import Todo.Application.TodoRepository (
    RepositoryError (..),
    TodoRepository (..),
 )
import Todo.Domain.Todo (
    Todo,
    TodoStatus (..),
    mkTodoTitle,
    restoreTodo,
    todoCompletedAt,
    todoCreatedAt,
    todoDescription,
    todoId,
    todoStatus,
    todoTitle,
    todoTitleText,
 )
import Todo.Domain.TodoId (TodoId, parseTodoId, renderTodoId)
import Todo.Infrastructure.Persistence.TodoRepository (statusFromDatabase, statusToDatabase)

type TodoRow = (Text, Text, Maybe Text, Text, UTCTime, Maybe UTCTime)

postgresTodoRepository :: DatabaseConfig -> TodoRepository IO
postgresTodoRepository config =
    TodoRepository
        { insertTodo = insertOne config
        , findTodoById = findOne config
        , listAllTodos = listAll config
        , saveTodo = saveOne config
        , deleteTodoById = deleteOne config
        }

withConnection :: DatabaseConfig -> (Connection -> IO a) -> IO a
withConnection config = bracket (connectDatabase config) close

asRepositoryResult :: IO a -> IO (Either RepositoryError a)
asRepositoryResult action = do
    result <- try action
    pure $ case result of
        Left exception -> Left (RepositoryError (Text.pack (show (exception :: SomeException))))
        Right value -> Right value

insertOne :: DatabaseConfig -> Todo -> IO (Either RepositoryError ())
insertOne config todo = asRepositoryResult $ withConnection config $ \conn -> do
    _ <-
        execute
            conn
            "INSERT INTO todos (id, title, description, status, created_at, completed_at) VALUES (?::uuid, ?, ?, ?, ?, ?)"
            ( renderTodoId (todoId todo)
            , todoTitleText (todoTitle todo)
            , todoDescription todo
            , statusToDatabase (todoStatus todo)
            , todoCreatedAt todo
            , todoCompletedAt todo
            )
    pure ()

findOne :: DatabaseConfig -> TodoId -> IO (Either RepositoryError (Maybe Todo))
findOne config ident = do
    queried <- asRepositoryResult $ withConnection config $ \conn ->
        query
            conn
            "SELECT id::text, title, description, status, created_at, completed_at FROM todos WHERE id = ?::uuid"
            (Only (renderTodoId ident))
    pure (queried >>= rowsToMaybeTodo)

listAll :: DatabaseConfig -> IO (Either RepositoryError [Todo])
listAll config = do
    queried <- asRepositoryResult $ withConnection config $ \conn ->
        query_
            conn
            "SELECT id::text, title, description, status, created_at, completed_at FROM todos ORDER BY created_at ASC, id ASC"
    pure (queried >>= traverse rowToTodo)

saveOne :: DatabaseConfig -> Todo -> IO (Either RepositoryError ())
saveOne config todo = asRepositoryResult $ withConnection config $ \conn -> do
    _ <-
        execute
            conn
            "UPDATE todos SET title = ?, description = ?, status = ?, completed_at = ? WHERE id = ?::uuid"
            ( todoTitleText (todoTitle todo)
            , todoDescription todo
            , statusToDatabase (todoStatus todo)
            , todoCompletedAt todo
            , renderTodoId (todoId todo)
            )
    pure ()

deleteOne :: DatabaseConfig -> TodoId -> IO (Either RepositoryError Bool)
deleteOne config ident = asRepositoryResult $ withConnection config $ \conn -> do
    affected <- execute conn "DELETE FROM todos WHERE id = ?::uuid" (Only (renderTodoId ident))
    pure (affected > (0 :: Int64))

rowsToMaybeTodo :: [TodoRow] -> Either RepositoryError (Maybe Todo)
rowsToMaybeTodo [] = Right Nothing
rowsToMaybeTodo (row : _) = Just <$> rowToTodo row

rowToTodo :: TodoRow -> Either RepositoryError Todo
rowToTodo (rawId, rawTitle, description, rawStatus, createdAt, completedAt) = do
    ident <- either (Left . RepositoryError) Right (parseTodoId rawId)
    title <- case mkTodoTitle rawTitle of
        Left err -> Left (RepositoryError ("Invalid title stored in database: " <> Text.pack (show err)))
        Right value -> Right value
    status <- statusFromDatabase rawStatus
    validateCompletion status completedAt
    pure (restoreTodo ident title description status createdAt completedAt)

validateCompletion :: TodoStatus -> Maybe UTCTime -> Either RepositoryError ()
validateCompletion Active Nothing = Right ()
validateCompletion Completed (Just _) = Right ()
validateCompletion _ _ = Left (RepositoryError "Inconsistent status/completed_at in database")
