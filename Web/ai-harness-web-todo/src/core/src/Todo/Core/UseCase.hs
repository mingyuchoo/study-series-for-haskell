{-# LANGUAGE DerivingStrategies #-}

-- | 애플리케이션 유스케이스입니다.
--
-- 저장 방식과 전송 방식에 독립적이며 'TodoRepository'에 대해 다형입니다.
-- CLI와 HTTP API는 이 모듈을 공유하므로 두 표면이 서로 다른 규칙을 갖지 않습니다.
-- 이는 @docs/product/invariants.md@의 @PROD-INV-003@을 지탱하는 구조적 근거입니다.
module Todo.Core.UseCase (
  UseCaseError (..),
  StatusChange (..),
  addTodo,
  listTodos,
  getTodo,
  changeStatus,
  startTodo,
  completeTodo,
  reopenTodo,
  archiveTodo,
  updateTodo,
  deleteTodo,
) where

import Data.Maybe (fromMaybe)
import Data.Time (UTCTime)
import Todo.Core.Filter (SortOrder, TodoFilter, applyFilter)
import Todo.Core.Repository (
  NewTodo,
  TodoPatch (..),
  TodoRepository (..),
 )
import Todo.Core.Status (TransitionError (..), transition)
import Todo.Core.Types (Status (..), Todo (..), TodoId)

-- | 유스케이스가 거부된 이유입니다.
data UseCaseError
  = TodoNotFound TodoId
  | InvalidTransition TodoId TransitionError
  deriving stock (Eq, Show)

-- | 상태 변경의 결과입니다. 멱등 재호출과 실제 변경을 구분합니다.
data StatusChange = StatusChange
  { changedTodo :: Todo
  , statusWasChanged :: Bool
  -- ^ 이미 목표 상태여서 저장소를 건드리지 않은 경우 'False'입니다.
  }
  deriving stock (Eq, Show)

-- | 새 할 일을 추가합니다.
addTodo :: (TodoRepository m) => NewTodo -> m Todo
addTodo = insertTodo

-- | 조건과 정렬을 적용해 목록을 조회합니다.
--
-- 조건 평가는 "Todo.Core.Filter"가 담당합니다. 저장소가 조건을 자체 구현하면
-- 표면마다 결과가 달라질 수 있으므로 여기서 한 번만 적용합니다.
listTodos :: (TodoRepository m) => TodoFilter -> SortOrder -> m [Todo]
listTodos f order = applyFilter f order <$> allTodos

-- | 하나의 할 일을 조회합니다.
getTodo :: (TodoRepository m) => TodoId -> m (Either UseCaseError Todo)
getTodo tid = maybe (Left (TodoNotFound tid)) Right <$> findTodo tid

-- | 상태를 변경합니다.
--
-- 이미 목표 상태이면 저장소를 건드리지 않고 성공으로 처리합니다. 같은 요청을
-- 여러 번 보내도 한 번의 효과만 남기기 위한 규칙입니다.
changeStatus
  :: (TodoRepository m)
  => UTCTime
  -- ^ 경계에서 주입한 변경 시각
  -> Status
  -> TodoId
  -> m (Either UseCaseError StatusChange)
changeStatus now target tid = do
  found <- findTodo tid
  case found of
    Nothing -> pure (Left (TodoNotFound tid))
    Just todo -> case transition (todoStatus todo) target of
      Left (SameStatus _) ->
        pure (Right (StatusChange todo False))
      Left err ->
        pure (Left (InvalidTransition tid err))
      Right next -> do
        let updated = todo{todoStatus = next, todoUpdatedAt = now}
        stored <- replaceTodo updated
        pure $
          if stored
            then Right (StatusChange updated True)
            else Left (TodoNotFound tid)

-- | 할 일을 진행 중으로 표시합니다.
startTodo :: (TodoRepository m) => UTCTime -> TodoId -> m (Either UseCaseError StatusChange)
startTodo now = changeStatus now InProgress

-- | 할 일을 완료로 표시합니다.
completeTodo :: (TodoRepository m) => UTCTime -> TodoId -> m (Either UseCaseError StatusChange)
completeTodo now = changeStatus now Done

-- | 완료했거나 진행 중이던 할 일을 대기 상태로 되돌립니다.
reopenTodo :: (TodoRepository m) => UTCTime -> TodoId -> m (Either UseCaseError StatusChange)
reopenTodo now = changeStatus now Pending

-- | 할 일을 보관합니다. 보관은 종료 상태입니다.
archiveTodo :: (TodoRepository m) => UTCTime -> TodoId -> m (Either UseCaseError StatusChange)
archiveTodo now = changeStatus now Archived

-- | 내용을 부분 수정합니다. 상태는 이 경로로 바꾸지 않습니다.
updateTodo
  :: (TodoRepository m)
  => UTCTime
  -- ^ 경계에서 주입한 변경 시각
  -> TodoPatch
  -> TodoId
  -> m (Either UseCaseError Todo)
updateTodo now patch tid = do
  found <- findTodo tid
  case found of
    Nothing -> pure (Left (TodoNotFound tid))
    Just todo -> do
      let updated =
            todo
              { todoTitle = fromMaybe (todoTitle todo) (patchTitle patch)
              , todoListId = fromMaybe (todoListId todo) (patchListId patch)
              , todoPriority = fromMaybe (todoPriority todo) (patchPriority patch)
              , todoTags = fromMaybe (todoTags todo) (patchTags patch)
              , todoDueOn = fromMaybe (todoDueOn todo) (patchDueOn patch)
              , todoUpdatedAt = now
              }
      stored <- replaceTodo updated
      pure $
        if stored
          then Right updated
          else Left (TodoNotFound tid)

-- | 할 일을 영구 삭제합니다.
--
-- 되돌릴 수 없으므로 어댑터는 사용자의 명시적 요청 없이 호출하지 않습니다
-- (@docs/product/invariants.md@의 @PROD-INV-001@).
deleteTodo :: (TodoRepository m) => TodoId -> m (Either UseCaseError ())
deleteTodo tid = do
  removed <- removeTodo tid
  pure $ if removed then Right () else Left (TodoNotFound tid)
