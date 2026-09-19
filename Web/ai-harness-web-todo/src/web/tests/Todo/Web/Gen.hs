{-# LANGUAGE OverloadedStrings #-}

-- | 테스트용 표본 값입니다.
--
-- @core@의 표본 생성기는 그 패키지의 테스트 스위트 안에만 있으므로 여기서 따로
-- 만듭니다. 시각은 고정값을 씁니다. 테스트가 시계에 의존하지 않게 하기 위함입니다
-- (@tests/README.md@).
module Todo.Web.Gen (
  fixedNow,
  fixedToday,
  sampleTodo,
) where

import qualified Data.Set as Set
import Data.Time (Day, UTCTime (..), fromGregorian, secondsToDiffTime)
import Todo.Core.Types (
  ListId (..),
  Priority (..),
  Status (..),
  Title (..),
  Todo (..),
  TodoId (..),
 )

fixedToday :: Day
fixedToday = fromGregorian 2026 8 23

fixedNow :: UTCTime
fixedNow = UTCTime fixedToday (secondsToDiffTime 0)

-- | 식별자만 다른 기본 할 일입니다. 필요한 필드는 호출하는 쪽이 갱신합니다.
sampleTodo :: Int -> Todo
sampleTodo n =
  Todo
    { todoId = TodoId n
    , todoTitle = Title "표본 할 일"
    , todoListId = ListId "inbox"
    , todoStatus = Pending
    , todoPriority = Normal
    , todoTags = Set.empty
    , todoDueOn = Nothing
    , todoCreatedAt = fixedNow
    , todoUpdatedAt = fixedNow
    }
