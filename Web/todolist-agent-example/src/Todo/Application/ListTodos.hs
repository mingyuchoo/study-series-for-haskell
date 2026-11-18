module Todo.Application.ListTodos (
    ListTodosError (..),
    execute,
) where

import Todo.Application.TodoRepository (TodoRepository (..))
import Todo.Domain.Todo (Todo)

data ListTodosError = ListTodosPersistenceFailure
    deriving (Eq, Show)

execute :: (Monad m) => TodoRepository m -> m (Either ListTodosError [Todo])
execute repo = do
    result <- listAllTodos repo
    pure $ case result of
        Left _ -> Left ListTodosPersistenceFailure
        Right todos -> Right todos
