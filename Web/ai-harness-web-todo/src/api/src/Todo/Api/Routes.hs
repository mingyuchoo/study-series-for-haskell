{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

-- | HTTP 라우트를 타입 수준에 고정합니다.
--
-- 이 타입이 라우트의 Canonical Source입니다. @docs/generated/route-map.md@는
-- @scripts/context/generate-route-map.sh@가 이 파일에서 추출하므로 라우트를
-- 바꾸면 생성 문서도 함께 바꿔야 하고, 잊으면 Context Integrity 검사가 실패합니다.
--
-- 사람이 읽는 계약은 @docs/contracts/api/TODO-API-v1.md@에 있습니다.
module Todo.Api.Routes (
  TodoApi,
  todoApi,
) where

import Data.Proxy (Proxy (..))
import Data.Text (Text)
import Servant.API
import Todo.Api.Types (NewTodoDto, PatchTodoDto, StatusDto, TodoDto)

-- | Todo API v1입니다.
type TodoApi =
  "todos" :> QueryParam "status" Text :> QueryParam "tag" Text :> QueryParam "list" Text :> Get '[JSON] [TodoDto]
    :<|> "todos" :> ReqBody '[JSON] NewTodoDto :> PostCreated '[JSON] TodoDto
    :<|> "todos" :> Capture "todoId" Int :> Get '[JSON] TodoDto
    :<|> "todos" :> Capture "todoId" Int :> ReqBody '[JSON] PatchTodoDto :> Patch '[JSON] TodoDto
    :<|> "todos" :> Capture "todoId" Int :> "status" :> ReqBody '[JSON] StatusDto :> Put '[JSON] TodoDto
    :<|> "todos" :> Capture "todoId" Int :> DeleteNoContent

-- | 서버와 클라이언트가 공유하는 증거 값입니다.
todoApi :: Proxy TodoApi
todoApi = Proxy
