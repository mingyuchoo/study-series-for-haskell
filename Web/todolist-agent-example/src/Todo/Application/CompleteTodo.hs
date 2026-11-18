module Todo.Application.CompleteTodo (
    CompleteTodoError (..),
    CompleteTodoDependencies (..),
    execute,
) where

import Data.Time (UTCTime)
import Todo.Application.TodoRepository (TodoRepository (..))
import Todo.Domain.Todo (Todo, completeTodo)
import Todo.Domain.TodoId (TodoId)

data CompleteTodoError = CompleteTodoNotFound | CompleteTodoPersistenceFailure
    deriving (Eq, Show)

data CompleteTodoDependencies m = CompleteTodoDependencies
    { completeRepository :: TodoRepository m
    , completionTime :: m UTCTime
    }

execute :: (Monad m) => CompleteTodoDependencies m -> TodoId -> m (Either CompleteTodoError Todo)
execute deps ident = do
    found <- findTodoById (completeRepository deps) ident
    case found of
        Left _ -> pure (Left CompleteTodoPersistenceFailure)
        Right Nothing -> pure (Left CompleteTodoNotFound)
        Right (Just existing) -> do
            now <- completionTime deps
            let completed = completeTodo now existing
            saved <- saveTodo (completeRepository deps) completed
            pure $ case saved of
                Left _ -> Left CompleteTodoPersistenceFailure
                Right () -> Right completed
