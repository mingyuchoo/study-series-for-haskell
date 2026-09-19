{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}

-- | 할 일 조회 조건과 정렬 규칙입니다.
--
-- 저장소가 이 규칙을 자체적으로 다시 구현하면 CLI와 HTTP API가 서로 다른 목록을
-- 보여줄 수 있습니다. 조회 의미의 Canonical Source는 이 모듈입니다.
module Todo.Core.Filter (
  StatusFilter (..),
  SortOrder (..),
  TodoFilter (..),
  emptyFilter,
  resolveStatusFilter,
  matches,
  sortTodos,
  applyFilter,
) where

import Data.List (sortOn)
import Data.Ord (Down (..))
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Time (Day)
import Todo.Core.Types (ListId, Status (..), Tag, Todo (..))

-- | 상태 조건입니다.
data StatusFilter
  = -- | 상태를 제한하지 않습니다.
    AnyStatus
  | -- | 정확히 하나의 상태만 봅니다.
    ExactStatus Status
  | -- | 아직 끝나지 않은 할 일만 봅니다. 'Done'과 'Archived'를 제외합니다.
    ActiveOnly
  deriving stock (Eq, Show)

-- | 목록 정렬 기준입니다.
data SortOrder
  = -- | 마감일 오름차순. 마감일이 없는 할 일은 뒤로 보냅니다.
    ByDueDate
  | -- | 우선순위 내림차순. 같은 우선순위는 마감일 순입니다.
    ByPriority
  | -- | 생성 시각 오름차순입니다.
    ByCreatedAt
  deriving stock (Eq, Show)

-- | 조회 조건입니다. 각 조건은 논리곱으로 결합합니다.
data TodoFilter = TodoFilter
  { filterStatus :: StatusFilter
  , filterTags :: Set Tag
  -- ^ 지정한 태그를 모두 가진 할 일만 봅니다.
  , filterListId :: Maybe ListId
  , filterDueOnOrBefore :: Maybe Day
  -- ^ 이 날짜 이하의 마감일을 가진 할 일만 봅니다.
  }
  deriving stock (Eq, Show)

-- | 아무것도 제한하지 않는 조건입니다.
emptyFilter :: TodoFilter
emptyFilter =
  TodoFilter
    { filterStatus = AnyStatus
    , filterTags = Set.empty
    , filterListId = Nothing
    , filterDueOnOrBefore = Nothing
    }

-- | 사람이 쓰는 표면의 상태 조건을 정합니다.
--
-- 우선순위는 명시한 상태, @전체 보기@, 기본값 순입니다. 기본값이 'ActiveOnly'인 것은
-- 목록을 여는 사람이 대개 남은 일을 보려 하기 때문입니다.
--
-- 이 함수가 도메인에 있는 이유는 규칙이어서가 아니라 표면이 여럿이기 때문입니다.
-- @cli@와 @web@이 각자 이 우선순위를 구현하면 같은 조건에서 서로 다른
-- 목록을 보여줄 수 있습니다(@docs/product/invariants.md@의 @PROD-INV-003@).
-- @api@는 스크립트가 쓰는 표면이므로 이 기본값을 쓰지 않고 조건을 명시합니다.
resolveStatusFilter :: Maybe Status -> Bool -> StatusFilter
resolveStatusFilter (Just status) _ = ExactStatus status
resolveStatusFilter Nothing True = AnyStatus
resolveStatusFilter Nothing False = ActiveOnly

-- | 하나의 할 일이 조건을 만족하는지 판단합니다.
matches :: TodoFilter -> Todo -> Bool
matches f todo =
  matchesStatus (filterStatus f) (todoStatus todo)
    && filterTags f `Set.isSubsetOf` todoTags todo
    && maybe True (== todoListId todo) (filterListId f)
    && matchesDue (filterDueOnOrBefore f) (todoDueOn todo)
 where
  matchesStatus = \case
    AnyStatus -> const True
    ExactStatus wanted -> (== wanted)
    ActiveOnly -> \status -> status /= Done && status /= Archived

  matchesDue Nothing _ = True
  matchesDue (Just _) Nothing = False
  matchesDue (Just limit) (Just due) = due <= limit

-- | 정렬 기준을 적용합니다. 같은 순위의 항목은 식별자 순으로 안정화합니다.
sortTodos :: SortOrder -> [Todo] -> [Todo]
sortTodos order = case order of
  ByDueDate -> sortOn (\t -> (dueKey t, todoId t))
  ByPriority -> sortOn (\t -> (Down (todoPriority t), dueKey t, todoId t))
  ByCreatedAt -> sortOn (\t -> (todoCreatedAt t, todoId t))
 where
  -- 마감일이 없는 할 일을 항상 뒤로 보내기 위한 정렬 키입니다.
  dueKey :: Todo -> (Bool, Maybe Day)
  dueKey t = (isNothingDue t, todoDueOn t)

  isNothingDue :: Todo -> Bool
  isNothingDue t = case todoDueOn t of
    Nothing -> True
    Just _ -> False

-- | 조건 적용과 정렬을 한 번에 수행합니다.
applyFilter :: TodoFilter -> SortOrder -> [Todo] -> [Todo]
applyFilter f order = sortTodos order . filter (matches f)
