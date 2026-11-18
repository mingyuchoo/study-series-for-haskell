{-# LANGUAGE OverloadedStrings #-}

module Todo.Domain.Todo (
    Todo,
    TodoTitle,
    TodoStatus (..),
    TodoTitleError (..),
    mkTodoTitle,
    todoTitleText,
    createTodo,
    restoreTodo,
    completeTodo,
    todoId,
    todoTitle,
    todoDescription,
    todoStatus,
    todoCreatedAt,
    todoCompletedAt,
) where

import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time (UTCTime)
import Todo.Domain.TodoId (TodoId)

newtype TodoTitle = TodoTitle Text
    deriving (Eq, Show)

data TodoStatus = Active | Completed
    deriving (Eq, Show)

data TodoTitleError = EmptyTodoTitle | TodoTitleTooLong
    deriving (Eq, Show)

data Todo = Todo
    { todoId :: TodoId
    , todoTitle :: TodoTitle
    , todoDescription :: Maybe Text
    , todoStatus :: TodoStatus
    , todoCreatedAt :: UTCTime
    , todoCompletedAt :: Maybe UTCTime
    }
    deriving (Eq, Show)

mkTodoTitle :: Text -> Either TodoTitleError TodoTitle
mkTodoTitle input
    | Text.null trimmed = Left EmptyTodoTitle
    | Text.length trimmed > 200 = Left TodoTitleTooLong
    | otherwise = Right (TodoTitle trimmed)
  where
    trimmed = Text.strip input

todoTitleText :: TodoTitle -> Text
todoTitleText (TodoTitle value) = value

createTodo :: TodoId -> UTCTime -> TodoTitle -> Maybe Text -> Todo
createTodo ident createdAt title description =
    Todo
        { todoId = ident
        , todoTitle = title
        , todoDescription = description
        , todoStatus = Active
        , todoCreatedAt = createdAt
        , todoCompletedAt = Nothing
        }

restoreTodo :: TodoId -> TodoTitle -> Maybe Text -> TodoStatus -> UTCTime -> Maybe UTCTime -> Todo
restoreTodo = Todo

completeTodo :: UTCTime -> Todo -> Todo
completeTodo completedAt todo =
    case todoStatus todo of
        Completed -> todo
        Active -> todo{todoStatus = Completed, todoCompletedAt = Just completedAt}
