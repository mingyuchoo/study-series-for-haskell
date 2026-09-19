{-# LANGUAGE OverloadedStrings #-}

-- | HTTP 요청을 유스케이스 호출로 옮기는 어댑터입니다.
--
-- CLI와 마찬가지로 여기에는 비즈니스 규칙이 없습니다. 두 표면이 같은
-- "Todo.Core.UseCase"를 호출하기 때문에 같은 규칙을 노출합니다.
module Todo.Api.Server (
  application,
  todoServer,
) where

import Control.Monad.IO.Class (liftIO)
import qualified Data.Aeson as Aeson
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, UTCTime, getCurrentTime, utctDay)
import Database.SQLite.Simple (Connection)
import Servant
import Todo.Api.Routes (TodoApi, todoApi)
import Todo.Api.Types (
  ApiError (..),
  NewTodoDto (..),
  PatchTodoDto (..),
  StatusDto (..),
  TodoDto,
  toTodoDto,
 )
import Todo.Core.Filter (
  SortOrder (..),
  StatusFilter (..),
  TodoFilter (..),
  emptyFilter,
 )
import Todo.Core.Repository (NewTodo (..), TodoPatch (..), emptyPatch)
import Todo.Core.Status (TransitionError (..))
import Todo.Core.Types (
  ListId,
  Priority (..),
  Status,
  Tag,
  TodoId (..),
  defaultListId,
  priorityFromName,
  statusFromName,
  statusName,
 )
import Todo.Core.UseCase (
  StatusChange (..),
  UseCaseError (..),
  addTodo,
  changeStatus,
  deleteTodo,
  getTodo,
  listTodos,
  updateTodo,
 )
import Todo.Core.Validation (
  ValidationError,
  mkListId,
  mkTags,
  mkTitle,
  renderValidationError,
  validateDueOn,
 )
import Todo.Store.Sqlite (SqliteT, runSqlite)

-- | 연결 하나에 묶인 WAI 애플리케이션입니다.
application :: Connection -> Application
application conn = serve todoApi (todoServer conn)

-- | 라우트 타입에 대응하는 핸들러 묶음입니다.
todoServer :: Connection -> Server TodoApi
todoServer conn =
  handleList conn
    :<|> handleCreate conn
    :<|> handleGet conn
    :<|> handlePatch conn
    :<|> handleStatus conn
    :<|> handleDelete conn

-- 핸들러 --------------------------------------------------------------------

handleList
  :: Connection
  -> Maybe Text
  -> Maybe Text
  -> Maybe Text
  -> Handler [TodoDto]
handleList conn rawStatus rawTag rawList = do
  status <- traverse (parseStatusName "status") rawStatus
  tags <- orBadRequest (mkTags (maybe [] pure rawTag))
  listId <- orBadRequest (traverse mkListId rawList)
  let todoFilter =
        emptyFilter
          { filterStatus = maybe AnyStatus ExactStatus status
          , filterTags = tags
          , filterListId = listId
          }
  todos <- run conn (listTodos todoFilter ByDueDate)
  pure (map toTodoDto todos)

handleCreate :: Connection -> NewTodoDto -> Handler TodoDto
handleCreate conn body = do
  now <- liftIO getCurrentTime
  new <- buildNewTodo now (utctDay now) body
  todo <- run conn (addTodo new)
  pure (toTodoDto todo)

handleGet :: Connection -> Int -> Handler TodoDto
handleGet conn rawId = do
  result <- run conn (getTodo (TodoId rawId))
  toTodoDto <$> orUseCaseError result

handlePatch :: Connection -> Int -> PatchTodoDto -> Handler TodoDto
handlePatch conn rawId body = do
  now <- liftIO getCurrentTime
  patch <- buildPatch body
  result <- run conn (updateTodo now patch (TodoId rawId))
  toTodoDto <$> orUseCaseError result

handleStatus :: Connection -> Int -> StatusDto -> Handler TodoDto
handleStatus conn rawId body = do
  now <- liftIO getCurrentTime
  target <- parseStatusName "status" (statusDtoStatus body)
  result <- run conn (changeStatus now target (TodoId rawId))
  change <- orUseCaseError result
  pure (toTodoDto (changedTodo change))

handleDelete :: Connection -> Int -> Handler NoContent
handleDelete conn rawId = do
  result <- run conn (deleteTodo (TodoId rawId))
  _ <- orUseCaseError result
  pure NoContent

-- 입력 변환 ------------------------------------------------------------------

buildNewTodo :: UTCTime -> Day -> NewTodoDto -> Handler NewTodo
buildNewTodo now today body = do
  title <- orBadRequest (mkTitle (newDtoTitle body))
  listId <- resolveListId (newDtoList body)
  priority <- maybe (pure Normal) (parsePriorityName "priority") (newDtoPriority body)
  tags <- resolveTags (newDtoTags body)
  dueOn <- orBadRequest (validateDueOn today (newDtoDueOn body))
  pure
    NewTodo
      { newTitle = title
      , newListId = listId
      , newPriority = priority
      , newTags = tags
      , newDueOn = dueOn
      , newCreatedAt = now
      }

buildPatch :: PatchTodoDto -> Handler TodoPatch
buildPatch body = do
  title <- orBadRequest (traverse mkTitle (patchDtoTitle body))
  listId <- orBadRequest (traverse mkListId (patchDtoList body))
  priority <- traverse (parsePriorityName "priority") (patchDtoPriority body)
  tags <- traverse (orBadRequest . mkTags) (patchDtoTags body)
  pure
    emptyPatch
      { patchTitle = title
      , patchListId = listId
      , patchPriority = priority
      , patchTags = tags
      , patchDueOn = patchDtoDueOn body
      }

resolveListId :: Maybe Text -> Handler ListId
resolveListId Nothing = pure defaultListId
resolveListId (Just raw) = orBadRequest (mkListId raw)

resolveTags :: Maybe [Text] -> Handler (Set Tag)
resolveTags Nothing = pure Set.empty
resolveTags (Just raws) = orBadRequest (mkTags raws)

parseStatusName :: Text -> Text -> Handler Status
parseStatusName field raw = case statusFromName raw of
  Just status -> pure status
  Nothing ->
    throwApiError
      err400
      (ApiError "invalid_request" (field <> " 값을 인식할 수 없습니다: " <> raw))

parsePriorityName :: Text -> Text -> Handler Priority
parsePriorityName field raw = case priorityFromName raw of
  Just priority -> pure priority
  Nothing ->
    throwApiError
      err400
      (ApiError "invalid_request" (field <> " 값을 인식할 수 없습니다: " <> raw))

-- 실행과 오류 매핑 ------------------------------------------------------------

run :: Connection -> SqliteT IO a -> Handler a
run conn action = liftIO (runSqlite conn action)

orBadRequest :: Either ValidationError a -> Handler a
orBadRequest (Right value) = pure value
orBadRequest (Left err) =
  throwApiError err400 (ApiError "invalid_request" (renderValidationError err))

-- | 유스케이스 오류를 안정적인 오류 코드와 HTTP 상태로 옮깁니다.
--
-- 매핑 규칙은 @docs/contracts/api/TODO-API-v1.md@의 오류 모델과 같아야 합니다.
orUseCaseError :: Either UseCaseError a -> Handler a
orUseCaseError (Right value) = pure value
orUseCaseError (Left (TodoNotFound (TodoId tid))) =
  throwApiError
    err404
    (ApiError "not_found" ("할 일을 찾을 수 없습니다: " <> T.pack (show tid)))
orUseCaseError (Left (InvalidTransition _ (SameStatus status))) =
  throwApiError
    err409
    (ApiError "invalid_transition" ("이미 " <> statusName status <> " 상태입니다."))
orUseCaseError (Left (InvalidTransition _ (ForbiddenTransition from to))) =
  throwApiError
    err409
    ( ApiError
        "invalid_transition"
        (statusName from <> "에서 " <> statusName to <> "(으)로 바꿀 수 없습니다.")
    )

throwApiError :: ServerError -> ApiError -> Handler a
throwApiError base body =
  throwError
    base
      { errBody = Aeson.encode body
      , errHeaders = [("Content-Type", "application/json;charset=utf-8")]
      }
