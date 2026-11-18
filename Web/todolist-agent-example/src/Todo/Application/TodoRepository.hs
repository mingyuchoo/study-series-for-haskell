module Todo.Application.TodoRepository (
    RepositoryError (..),
    TodoRepository (..),
) where

import Data.Text (Text)
import Todo.Domain.Todo (Todo)
import Todo.Domain.TodoId (TodoId)

newtype RepositoryError = RepositoryError Text
    deriving (Eq, Show)

data TodoRepository m = TodoRepository
    { insertTodo :: Todo -> m (Either RepositoryError ())
    , findTodoById :: TodoId -> m (Either RepositoryError (Maybe Todo))
    , listAllTodos :: m (Either RepositoryError [Todo])
    , saveTodo :: Todo -> m (Either RepositoryError ())
    , deleteTodoById :: TodoId -> m (Either RepositoryError Bool)
    }
