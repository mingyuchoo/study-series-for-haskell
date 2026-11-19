module Infrastructure.Repository (sqliteRepository) where

import Control.Exception
  ( Exception
  , SomeAsyncException
  , SomeException
  , catch
  , displayException
  , fromException
  , throwIO
  )
import Control.Monad (unless)
import DB qualified
import Data.List (find)
import Database.SQLite.Simple (Connection, changes, withTransaction)
import Todo.Application.Repository (Repository (..))
import Todo.Application.Types (WorkflowError (..))
import Todo.Domain.Model qualified as Domain
import TodoStatus qualified as Status

newtype RepositoryException = RepositoryException WorkflowError
  deriving (Show)

instance Exception RepositoryException

sqliteRepository :: Connection -> Repository IO
sqliteRepository connection =
  Repository
    { fetchTodos =
        transaction connection $ DB.getAllTodos connection >>= require . traverse decodeRow
    , insertTodo = transaction connection . insertConfirmed connection
    , updateFields = \target -> transaction connection . updateConfirmed connection target
    , removeTodo = transaction connection . deleteConfirmed connection
    , setStatus = \target before -> transaction connection . changeConfirmed connection target before
    }

insertConfirmed :: Connection -> Domain.TodoFields -> IO Domain.Todo
insertConfirmed connection value = do
  target <-
    DB.createTodoWithFields
      connection
      (Domain.action value)
      (Domain.subject value)
      (Domain.indirectObject value)
      (Domain.directObject value)
  confirmWrite connection
  loadTodo connection target

updateConfirmed :: Connection -> Domain.TodoId -> Domain.TodoFields -> IO Domain.Todo
updateConfirmed connection target value = do
  _ <- loadTodo connection target
  DB.updateTodoWithFields
    connection
    target
    (Domain.action value)
    (Domain.subject value)
    (Domain.indirectObject value)
    (Domain.directObject value)
  confirmWrite connection
  loadTodo connection target

deleteConfirmed :: Connection -> Domain.TodoId -> IO ()
deleteConfirmed connection target = do
  _ <- loadTodo connection target
  DB.deleteTodo connection target
  confirmWrite connection
  remaining <- DB.getAllTodos connection
  unless (all ((/= target) . DB.todoId) remaining) $ abort WriteNotApplied

changeConfirmed
  :: Connection
  -> Domain.TodoId
  -> Status.TodoStatusType
  -> Status.TodoStatusType
  -> IO Domain.Todo
changeConfirmed connection target before after = do
  todo <- loadTodo connection target
  unless (Domain.status todo == before && Status.nextStatus before == after)
    $ abort
    $ StaleStatus target
  case after of
    Status.Registered -> DB.transitionToRegistered connection target
    Status.InProgress -> DB.transitionToInProgress connection target
    Status.Cancelled -> DB.transitionToCancelled connection target
    Status.Completed -> DB.transitionToCompleted connection target
  confirmWrite connection
  updated <- loadTodo connection target
  unless (Domain.status updated == after) $ abort $ StaleStatus target
  pure updated

confirmWrite :: Connection -> IO ()
confirmWrite connection = do
  affected <- changes connection
  unless (affected == 1) $ abort WriteNotApplied

loadTodo :: Connection -> Domain.TodoId -> IO Domain.Todo
loadTodo connection target = do
  rows <- DB.getAllTodos connection
  case find ((== target) . DB.todoId) rows of
    Nothing -> abort $ MissingTodo target
    Just row -> require $ decodeRow row

decodeRow :: DB.TodoRow -> Either WorkflowError Domain.Todo
decodeRow row = do
  typedStatus <-
    maybe (Left $ InvalidStoredStatus (DB.todoId row) (DB.todoStatus row)) Right
      $ Status.parseStatus
      $ DB.todoStatus row
  value <-
    either (Left . InvalidFields) Right $
      Domain.validateFields
        (DB.todoAction row)
        (DB.todoSubject row)
        (DB.todoIndirectObject row)
        (DB.todoDirectObject row)
  pure $
    Domain.Todo
      (DB.todoId row)
      value
      typedStatus
      (DB.todoCreatedAt row)
      (DB.todoStatusChangedAt row)

require :: Either WorkflowError a -> IO a
require = either abort pure

abort :: WorkflowError -> IO a
abort = throwIO . RepositoryException

transaction :: Connection -> IO a -> IO (Either WorkflowError a)
transaction connection operation = (Right <$> withTransaction connection operation) `catch` handleFailure

handleFailure :: SomeException -> IO (Either WorkflowError a)
handleFailure exception = case fromException exception of
  Just (RepositoryException problem) -> pure $ Left problem
  Nothing -> case fromException exception :: Maybe SomeAsyncException of
    Just _ -> throwIO exception
    Nothing -> pure $ Left $ RepositoryFailure $ displayException exception
