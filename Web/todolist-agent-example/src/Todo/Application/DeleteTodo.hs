module Todo.Application.DeleteTodo (
    DeleteTodoError (..),
    execute,
) where

import Todo.Application.TodoRepository (TodoRepository (..))
import Todo.Domain.TodoId (TodoId)

data DeleteTodoError = DeleteTodoNotFound | DeleteTodoPersistenceFailure
    deriving (Eq, Show)

execute :: (Monad m) => TodoRepository m -> TodoId -> m (Either DeleteTodoError ())
execute repo ident = do
    result <- deleteTodoById repo ident
    pure $ case result of
        Left _ -> Left DeleteTodoPersistenceFailure
        Right False -> Left DeleteTodoNotFound
        Right True -> Right ()
