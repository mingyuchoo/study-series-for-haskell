{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module Todo.Interface.HTTP.API (
    TodoAPI,
    todoApiProxy,
) where

import Data.Proxy (Proxy (..))
import Data.Text (Text)
import Servant (
    Capture,
    DeleteNoContent,
    Get,
    JSON,
    Post,
    PostCreated,
    ReqBody,
    (:<|>),
    (:>),
 )
import Todo.Interface.HTTP.DTO (CreateTodoRequest, TodoListResponse, TodoResponse)

type TodoAPI =
    "api"
        :> "v1"
        :> "todos"
        :> ( ReqBody '[JSON] CreateTodoRequest :> PostCreated '[JSON] TodoResponse
                :<|> Get '[JSON] TodoListResponse
                :<|> Capture "todoId" Text :> Get '[JSON] TodoResponse
                :<|> Capture "todoId" Text :> "complete" :> Post '[JSON] TodoResponse
                :<|> Capture "todoId" Text :> DeleteNoContent
           )

todoApiProxy :: Proxy TodoAPI
todoApiProxy = Proxy
