{-# LANGUAGE OverloadedStrings #-}

module Todo.Interface.HTTP.DTO (
    CreateTodoRequest (..),
    TodoResponse (..),
    TodoListResponse (..),
    ErrorResponse (..),
    toTodoResponse,
) where

import Data.Aeson (
    FromJSON (..),
    ToJSON (..),
    object,
    withObject,
    (.:),
    (.:?),
    (.=),
 )
import Data.Text (Text)
import Data.Time (UTCTime)
import Todo.Domain.Todo (
    Todo,
    TodoStatus (..),
    todoCompletedAt,
    todoCreatedAt,
    todoDescription,
    todoId,
    todoStatus,
    todoTitle,
    todoTitleText,
 )
import Todo.Domain.TodoId (renderTodoId)

data CreateTodoRequest = CreateTodoRequest
    { requestTitle :: Text
    , requestDescription :: Maybe Text
    }
    deriving (Eq, Show)

instance FromJSON CreateTodoRequest where
    parseJSON = withObject "CreateTodoRequest" $ \obj ->
        CreateTodoRequest <$> obj .: "title" <*> obj .:? "description"

data TodoResponse = TodoResponse
    { responseId :: Text
    , responseTitle :: Text
    , responseDescription :: Maybe Text
    , responseStatus :: Text
    , responseCreatedAt :: UTCTime
    , responseCompletedAt :: Maybe UTCTime
    }
    deriving (Eq, Show)

instance ToJSON TodoResponse where
    toJSON value =
        object
            [ "id" .= responseId value
            , "title" .= responseTitle value
            , "description" .= responseDescription value
            , "status" .= responseStatus value
            , "createdAt" .= responseCreatedAt value
            , "completedAt" .= responseCompletedAt value
            ]

newtype TodoListResponse = TodoListResponse {responseItems :: [TodoResponse]}
    deriving (Eq, Show)

instance ToJSON TodoListResponse where
    toJSON value = object ["items" .= responseItems value]

data ErrorResponse = ErrorResponse
    { errorCode :: Text
    , errorMessage :: Text
    }
    deriving (Eq, Show)

instance ToJSON ErrorResponse where
    toJSON value =
        object
            [ "code" .= errorCode value
            , "message" .= errorMessage value
            ]

toTodoResponse :: Todo -> TodoResponse
toTodoResponse todo =
    TodoResponse
        { responseId = renderTodoId (todoId todo)
        , responseTitle = todoTitleText (todoTitle todo)
        , responseDescription = todoDescription todo
        , responseStatus = statusText (todoStatus todo)
        , responseCreatedAt = todoCreatedAt todo
        , responseCompletedAt = todoCompletedAt todo
        }
  where
    statusText Active = "active"
    statusText Completed = "completed"
