{-# LANGUAGE OverloadedStrings #-}

-- | 조회 조건과 정렬 규칙 검증입니다.
--
-- CLI와 HTTP API가 같은 목록을 보여준다는 @PROD-INV-003@의 근거가 되는 규칙입니다.
module Todo.Core.FilterSpec (spec) where

import qualified Data.Set as Set
import Data.Time (addDays)
import Test.Hspec (Spec, describe, it, shouldBe)
import Todo.Core.Filter (
  SortOrder (..),
  StatusFilter (..),
  TodoFilter (..),
  applyFilter,
  emptyFilter,
  matches,
  resolveStatusFilter,
 )
import Todo.Core.Gen (fixedToday, sampleTodo)
import Todo.Core.Types (
  ListId (..),
  Priority (..),
  Status (..),
  Tag (..),
  Todo (..),
  TodoId (..),
 )

pending1 :: Todo
pending1 = (sampleTodo 1){todoTags = Set.fromList [Tag "work"]}

done2 :: Todo
done2 = (sampleTodo 2){todoStatus = Done, todoTags = Set.fromList [Tag "work", Tag "home"]}

archived3 :: Todo
archived3 = (sampleTodo 3){todoStatus = Archived, todoListId = ListId "home"}

spec :: Spec
spec = describe "Todo.Core.Filter" $ do
  describe "matches" $ do
    it "기본 조건은 모든 할 일을 통과시킨다" $
      map (matches emptyFilter) [pending1, done2, archived3] `shouldBe` [True, True, True]

    it "ActiveOnly는 완료와 보관을 제외한다" $
      let f = emptyFilter{filterStatus = ActiveOnly}
       in map (matches f) [pending1, done2, archived3] `shouldBe` [True, False, False]

    it "ExactStatus는 정확히 하나의 상태만 통과시킨다" $
      let f = emptyFilter{filterStatus = ExactStatus Done}
       in map (matches f) [pending1, done2, archived3] `shouldBe` [False, True, False]

    it "태그 조건은 논리곱이다" $
      let f = emptyFilter{filterTags = Set.fromList [Tag "work", Tag "home"]}
       in map (matches f) [pending1, done2] `shouldBe` [False, True]

    it "목록 조건은 정확히 일치해야 한다" $
      let f = emptyFilter{filterListId = Just (ListId "home")}
       in map (matches f) [pending1, archived3] `shouldBe` [False, True]

    it "마감일 조건이 있으면 마감일 없는 할 일은 제외한다" $
      let f = emptyFilter{filterDueOnOrBefore = Just fixedToday}
       in matches f pending1 `shouldBe` False

  describe "sortTodos" $ do
    it "마감일이 없는 할 일을 뒤로 보낸다" $
      let withDue = (sampleTodo 10){todoDueOn = Just (addDays 3 fixedToday)}
          withoutDue = sampleTodo 11
          sorted = applyFilter emptyFilter ByDueDate [withoutDue, withDue]
       in map todoId sorted `shouldBe` [TodoId 10, TodoId 11]

    it "우선순위는 높은 것부터 정렬한다" $
      let low = (sampleTodo 20){todoPriority = Low}
          urgent = (sampleTodo 21){todoPriority = Urgent}
          normal = (sampleTodo 22){todoPriority = Normal}
          sorted = applyFilter emptyFilter ByPriority [low, normal, urgent]
       in map todoId sorted `shouldBe` [TodoId 21, TodoId 22, TodoId 20]

    it "같은 순위는 식별자 순으로 안정화한다" $
      let a = sampleTodo 31
          b = sampleTodo 30
          sorted = applyFilter emptyFilter ByPriority [a, b]
       in map todoId sorted `shouldBe` [TodoId 30, TodoId 31]

  describe "resolveStatusFilter" $ do
    -- 이 우선순위는 cli와 web이 함께 씁니다. 한쪽만 바꾸면 두 표면이
    -- 같은 조건에서 다른 목록을 보여줍니다.
    it "기본값은 끝나지 않은 할 일만 본다" $
      resolveStatusFilter Nothing False `shouldBe` ActiveOnly

    it "전체 보기를 켜면 상태를 제한하지 않는다" $
      resolveStatusFilter Nothing True `shouldBe` AnyStatus

    it "명시한 상태가 전체 보기보다 우선한다" $
      resolveStatusFilter (Just Done) True `shouldBe` ExactStatus Done

    it "명시한 상태는 전체 보기가 꺼져 있어도 그대로 적용된다" $
      resolveStatusFilter (Just Archived) False `shouldBe` ExactStatus Archived
