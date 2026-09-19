{-# LANGUAGE OverloadedStrings #-}

-- | 테스트용 생성기와 결정적인 고정값입니다.
module Todo.Core.Gen (
  fixedNow,
  fixedToday,
  sampleTodo,
  arbitraryStatus,
  arbitraryPriority,
) where

import qualified Data.Set as Set
import Data.Time (Day, UTCTime (..), fromGregorian, secondsToDiffTime)
import Test.QuickCheck (Gen, elements)
import Todo.Core.Types (
  ListId (..),
  Priority (..),
  Status (..),
  Title (..),
  Todo (..),
  TodoId (..),
 )

-- | 테스트가 시계에 의존하지 않도록 고정한 기준 시각입니다.
fixedNow :: UTCTime
fixedNow = UTCTime (fromGregorian 2026 8 22) (secondsToDiffTime 0)

-- | 'fixedNow'와 같은 날짜입니다.
fixedToday :: Day
fixedToday = fromGregorian 2026 8 22

-- | 최소한의 필드만 채운 기본 할 일입니다.
sampleTodo :: Int -> Todo
sampleTodo n =
  Todo
    { todoId = TodoId n
    , todoTitle = Title "예시 할 일"
    , todoListId = ListId "inbox"
    , todoStatus = Pending
    , todoPriority = Normal
    , todoTags = Set.empty
    , todoDueOn = Nothing
    , todoCreatedAt = fixedNow
    , todoUpdatedAt = fixedNow
    }

arbitraryStatus :: Gen Status
arbitraryStatus = elements [minBound .. maxBound]

arbitraryPriority :: Gen Priority
arbitraryPriority = elements [minBound .. maxBound]
