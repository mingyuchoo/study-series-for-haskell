{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Todo 도메인의 어휘를 정의합니다.
--
-- 이 모듈은 전송 형식이나 저장 형식을 알지 못합니다. 직렬화는 어댑터가 담당하고
-- 여기서는 도메인 의미만 표현합니다. 용어 정의는 @docs/product/terminology.md@,
-- 비즈니스 규칙은 @docs/domain/task.md@를 Canonical Source로 사용합니다.
module Todo.Core.Types (
  -- * 식별자
  TodoId (..),
  ListId (..),
  defaultListId,

  -- * 값 객체
  Title (..),
  Tag (..),

  -- * 열거형
  Status (..),
  Priority (..),
  statusName,
  statusFromName,
  priorityName,
  priorityFromName,

  -- * 개체
  Todo (..),
) where

import Data.Set (Set)
import Data.Text (Text)
import Data.Time (Day, UTCTime)

-- | 저장소가 부여하는 변경되지 않는 내부 식별자입니다.
newtype TodoId = TodoId {unTodoId :: Int}
  deriving stock (Eq, Ord, Show)

-- | 할 일이 속한 목록의 식별자입니다.
newtype ListId = ListId {unListId :: Text}
  deriving stock (Eq, Ord, Show)

-- | 목록을 지정하지 않은 할 일이 속하는 기본 목록입니다.
defaultListId :: ListId
defaultListId = ListId "inbox"

-- | 정규화된 제목입니다. 생성은 "Todo.Core.Validation"의 @mkTitle@만 사용합니다.
newtype Title = Title {unTitle :: Text}
  deriving stock (Eq, Ord, Show)

-- | 정규화된 태그입니다. 생성은 "Todo.Core.Validation"의 @mkTag@만 사용합니다.
newtype Tag = Tag {unTag :: Text}
  deriving stock (Eq, Ord, Show)

-- | 할 일의 수명 주기 상태입니다. 허용된 전이는 "Todo.Core.Status"가 소유합니다.
data Status
  = Pending
  | InProgress
  | Done
  | Archived
  deriving stock (Eq, Ord, Show, Enum, Bounded)

-- | 사용자가 지정하는 상대적 중요도입니다.
data Priority
  = Low
  | Normal
  | High
  | Urgent
  deriving stock (Eq, Ord, Show, Enum, Bounded)

-- | 저장과 전송 계층이 공유하는 안정적인 상태 이름입니다.
statusName :: Status -> Text
statusName = \case
  Pending -> "pending"
  InProgress -> "in_progress"
  Done -> "done"
  Archived -> "archived"

-- | 'statusName'의 역함수입니다. 알 수 없는 이름은 'Nothing'입니다.
statusFromName :: Text -> Maybe Status
statusFromName name =
  lookup name [(statusName s, s) | s <- [minBound .. maxBound]]

-- | 저장과 전송 계층이 공유하는 안정적인 우선순위 이름입니다.
priorityName :: Priority -> Text
priorityName = \case
  Low -> "low"
  Normal -> "normal"
  High -> "high"
  Urgent -> "urgent"

-- | 'priorityName'의 역함수입니다. 알 수 없는 이름은 'Nothing'입니다.
priorityFromName :: Text -> Maybe Priority
priorityFromName name =
  lookup name [(priorityName p, p) | p <- [minBound .. maxBound]]

-- | 하나의 할 일입니다.
--
-- @todoCreatedAt@과 @todoUpdatedAt@은 도메인이 스스로 만들지 않고 경계에서 주입받습니다.
-- 순수 계층이 시계에 의존하지 않게 하기 위한 결정이며 @docs/decisions/ADR-0002-effect-boundary.md@에 기록되어 있습니다.
data Todo = Todo
  { todoId :: TodoId
  , todoTitle :: Title
  , todoListId :: ListId
  , todoStatus :: Status
  , todoPriority :: Priority
  , todoTags :: Set Tag
  , todoDueOn :: Maybe Day
  , todoCreatedAt :: UTCTime
  , todoUpdatedAt :: UTCTime
  }
  deriving stock (Eq, Show)
