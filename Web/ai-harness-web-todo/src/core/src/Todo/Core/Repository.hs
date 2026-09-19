{-# LANGUAGE DerivingStrategies #-}

-- | 도메인이 소유하는 저장 포트입니다.
--
-- 의존 방향을 뒤집기 위해 인터페이스를 도메인 쪽에 두고 어댑터가 구현합니다.
-- 근거는 @docs/decisions/ADR-0002-effect-boundary.md@에 있습니다.
--
-- 이 포트에는 시계가 없습니다. 시각은 항상 경계에서 주입하며 도메인은 시간을
-- 스스로 읽지 않습니다. 덕분에 유스케이스 테스트가 결정적입니다.
module Todo.Core.Repository (
  NewTodo (..),
  TodoPatch (..),
  emptyPatch,
  TodoRepository (..),
) where

import Data.Set (Set)
import Data.Time (Day, UTCTime)
import Todo.Core.Types (ListId, Priority, Tag, Title, Todo, TodoId)

-- | 아직 식별자가 없는 새 할 일입니다.
data NewTodo = NewTodo
  { newTitle :: Title
  , newListId :: ListId
  , newPriority :: Priority
  , newTags :: Set Tag
  , newDueOn :: Maybe Day
  , newCreatedAt :: UTCTime
  -- ^ 경계에서 주입한 생성 시각입니다.
  }
  deriving stock (Eq, Show)

-- | 부분 수정 요청입니다. 'Nothing'은 해당 필드를 바꾸지 않는다는 뜻입니다.
--
-- 마감일은 값을 지우는 것과 바꾸지 않는 것을 구분해야 하므로 이중 'Maybe'를 사용합니다.
data TodoPatch = TodoPatch
  { patchTitle :: Maybe Title
  , patchListId :: Maybe ListId
  , patchPriority :: Maybe Priority
  , patchTags :: Maybe (Set Tag)
  , patchDueOn :: Maybe (Maybe Day)
  }
  deriving stock (Eq, Show)

-- | 아무것도 바꾸지 않는 수정 요청입니다.
emptyPatch :: TodoPatch
emptyPatch =
  TodoPatch
    { patchTitle = Nothing
    , patchListId = Nothing
    , patchPriority = Nothing
    , patchTags = Nothing
    , patchDueOn = Nothing
    }

-- | 할 일 저장 포트입니다.
--
-- 구현은 다음을 보장해야 합니다.
--
-- * @insertTodo@는 새 'TodoId'를 부여하고 저장된 값을 그대로 돌려줍니다.
-- * @replaceTodo@는 존재하지 않는 식별자에 대해 아무 것도 하지 않고 'False'를 반환합니다.
-- * @removeTodo@는 이미 없는 식별자에 대해 'False'를 반환하며 오류를 던지지 않습니다.
class (Monad m) => TodoRepository m where
  insertTodo :: NewTodo -> m Todo
  findTodo :: TodoId -> m (Maybe Todo)
  allTodos :: m [Todo]
  replaceTodo :: Todo -> m Bool
  removeTodo :: TodoId -> m Bool
