module Todo.Application.GetTodo (
    GetTodoError (..),
    execute,
) where

import Todo.Application.TodoRepository (TodoRepository (..))
import Todo.Domain.Todo (Todo)
import Todo.Domain.TodoId (TodoId)

data GetTodoError = GetTodoNotFound | GetTodoPersistenceFailure
    deriving (Eq, Show)

execute :: (Monad m) => TodoRepository m -> TodoId -> m (Either GetTodoError Todo)
execute repo ident = do
    result <- findTodoById repo ident
    pure $ case result of
        Left _ -> Left GetTodoPersistenceFailure
        Right Nothing -> Left GetTodoNotFound
        Right (Just todo) -> Right todo
