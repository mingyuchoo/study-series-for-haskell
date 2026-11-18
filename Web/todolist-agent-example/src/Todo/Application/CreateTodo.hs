module Todo.Application.CreateTodo (
    CreateTodoCommand (..),
    CreateTodoError (..),
    CreateTodoDependencies (..),
    execute,
) where

import Data.Text (Text)
import Data.Time (UTCTime)
import Todo.Application.TodoRepository (TodoRepository (..))
import Todo.Domain.Todo (Todo, TodoTitleError, createTodo, mkTodoTitle)
import Todo.Domain.TodoId (TodoId)

data CreateTodoCommand = CreateTodoCommand
    { commandTitle :: Text
    , commandDescription :: Maybe Text
    }
    deriving (Eq, Show)

data CreateTodoError
    = InvalidTodoTitle TodoTitleError
    | CreateTodoPersistenceFailure
    deriving (Eq, Show)

data CreateTodoDependencies m = CreateTodoDependencies
    { createRepository :: TodoRepository m
    , generateTodoId :: m TodoId
    , currentTime :: m UTCTime
    }

execute :: (Monad m) => CreateTodoDependencies m -> CreateTodoCommand -> m (Either CreateTodoError Todo)
execute deps command =
    case mkTodoTitle (commandTitle command) of
        Left err -> pure (Left (InvalidTodoTitle err))
        Right title -> do
            ident <- generateTodoId deps
            now <- currentTime deps
            let todo = createTodo ident now title (commandDescription command)
            persisted <- insertTodo (createRepository deps) todo
            pure $ case persisted of
                Left _ -> Left CreateTodoPersistenceFailure
                Right () -> Right todo
