{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module Todo.Interface.HTTP.Handler (
    HandlerEnv (..),
    todoServer,
) where

import Control.Monad.IO.Class (liftIO)
import Data.Aeson (encode)
import Data.Text (Text)
import Data.Time (UTCTime)
import Servant (
    Handler,
    NoContent (..),
    Server,
    ServerError,
    err400,
    err404,
    err500,
    errBody,
    throwError,
    (:<|>) (..),
 )
import Todo.Application.CompleteTodo qualified as Complete
import Todo.Application.CreateTodo qualified as Create
import Todo.Application.DeleteTodo qualified as Delete
import Todo.Application.GetTodo qualified as Get
import Todo.Application.ListTodos qualified as List
import Todo.Application.TodoRepository (TodoRepository)
import Todo.Domain.TodoId (TodoId, parseTodoId)
import Todo.Interface.HTTP.API (TodoAPI)
import Todo.Interface.HTTP.DTO (
    CreateTodoRequest (..),
    ErrorResponse (..),
    TodoListResponse (..),
    TodoResponse,
    toTodoResponse,
 )

data HandlerEnv = HandlerEnv
    { handlerRepository :: TodoRepository IO
    , handlerGenerateTodoId :: IO TodoId
    , handlerCurrentTime :: IO UTCTime
    }

todoServer :: HandlerEnv -> Server TodoAPI
todoServer env =
    createHandler env
        :<|> listHandler env
        :<|> getHandler env
        :<|> completeHandler env
        :<|> deleteHandler env

createHandler :: HandlerEnv -> CreateTodoRequest -> Handler TodoResponse
createHandler env request = do
    result <- liftIOEither $ Create.execute deps command
    case result of
        Left (Create.InvalidTodoTitle _) -> throwJson err400 "INVALID_TITLE" "Todo title must be between 1 and 200 non-whitespace characters."
        Left Create.CreateTodoPersistenceFailure -> throwJson err500 "INTERNAL_ERROR" "Internal server error"
        Right todo -> pure (toTodoResponse todo)
  where
    command = Create.CreateTodoCommand (requestTitle request) (requestDescription request)
    deps =
        Create.CreateTodoDependencies
            { Create.createRepository = handlerRepository env
            , Create.generateTodoId = handlerGenerateTodoId env
            , Create.currentTime = handlerCurrentTime env
            }

listHandler :: HandlerEnv -> Handler TodoListResponse
listHandler env = do
    result <- liftIOEither (List.execute (handlerRepository env))
    case result of
        Left List.ListTodosPersistenceFailure -> throwJson err500 "INTERNAL_ERROR" "Internal server error"
        Right todos -> pure (TodoListResponse (map toTodoResponse todos))

getHandler :: HandlerEnv -> Text -> Handler TodoResponse
getHandler env rawId = do
    ident <- parseId rawId
    result <- liftIOEither (Get.execute (handlerRepository env) ident)
    case result of
        Left Get.GetTodoNotFound -> throwJson err404 "TODO_NOT_FOUND" "Todo not found"
        Left Get.GetTodoPersistenceFailure -> throwJson err500 "INTERNAL_ERROR" "Internal server error"
        Right todo -> pure (toTodoResponse todo)

completeHandler :: HandlerEnv -> Text -> Handler TodoResponse
completeHandler env rawId = do
    ident <- parseId rawId
    let deps =
            Complete.CompleteTodoDependencies
                { Complete.completeRepository = handlerRepository env
                , Complete.completionTime = handlerCurrentTime env
                }
    result <- liftIOEither (Complete.execute deps ident)
    case result of
        Left Complete.CompleteTodoNotFound -> throwJson err404 "TODO_NOT_FOUND" "Todo not found"
        Left Complete.CompleteTodoPersistenceFailure -> throwJson err500 "INTERNAL_ERROR" "Internal server error"
        Right todo -> pure (toTodoResponse todo)

deleteHandler :: HandlerEnv -> Text -> Handler NoContent
deleteHandler env rawId = do
    ident <- parseId rawId
    result <- liftIOEither (Delete.execute (handlerRepository env) ident)
    case result of
        Left Delete.DeleteTodoNotFound -> throwJson err404 "TODO_NOT_FOUND" "Todo not found"
        Left Delete.DeleteTodoPersistenceFailure -> throwJson err500 "INTERNAL_ERROR" "Internal server error"
        Right () -> pure NoContent

parseId :: Text -> Handler TodoId
parseId raw =
    case parseTodoId raw of
        Left _ -> throwJson err400 "INVALID_TODO_ID" "Todo ID must be a valid UUID"
        Right ident -> pure ident

liftIOEither :: IO a -> Handler a
liftIOEither = liftIO

throwJson :: ServerError -> Text -> Text -> Handler a
throwJson base code message =
    throwError base{errBody = encode (ErrorResponse code message)}
