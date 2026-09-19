{-# LANGUAGE OverloadedStrings #-}

-- | 출력 형식 검증입니다.
--
-- 형식은 사용자와 스크립트가 함께 의존하므로 변경을 자유롭게 두지 않습니다.
module Todo.Cli.RenderSpec (spec) where

import qualified Data.Set as Set
import qualified Data.Text as T
import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import Test.Hspec (Spec, describe, it, shouldBe, shouldSatisfy)
import Todo.Cli.Render (renderTodoLine, renderTodoList, renderUseCaseError)
import Todo.Core.Status (TransitionError (..))
import Todo.Core.Types (
  ListId (..),
  Priority (..),
  Status (..),
  Tag (..),
  Title (..),
  Todo (..),
  TodoId (..),
 )
import Todo.Core.UseCase (UseCaseError (..))

sample :: Todo
sample =
  Todo
    { todoId = TodoId 1
    , todoTitle = Title "보고서 작성"
    , todoListId = ListId "inbox"
    , todoStatus = Pending
    , todoPriority = Normal
    , todoTags = Set.empty
    , todoDueOn = Nothing
    , todoCreatedAt = fixedNow
    , todoUpdatedAt = fixedNow
    }
 where
  fixedNow = UTCTime (fromGregorian 2026 8 22) (secondsToDiffTime 0)

spec :: Spec
spec = describe "Todo.Cli.Render" $ do
  it "식별자와 상태와 제목을 한 줄에 담는다" $
    renderTodoLine sample `shouldBe` "   1  pending      보고서 작성"

  it "태그는 정렬해 대괄호로 묶는다" $
    renderTodoLine sample{todoTags = Set.fromList [Tag "work", Tag "home"]}
      `shouldSatisfy` T.isInfixOf "[home work]"

  it "마감일이 있으면 함께 표시한다" $
    renderTodoLine sample{todoDueOn = Just (fromGregorian 2026 9 1)}
      `shouldSatisfy` T.isInfixOf "(마감 2026-09-01)"

  it "높은 우선순위는 눈에 띄는 표시를 붙인다" $
    renderTodoLine sample{todoPriority = Urgent} `shouldSatisfy` T.isInfixOf "!! 보고서 작성"

  it "빈 목록은 안내 문구를 보여준다" $
    renderTodoList [] `shouldBe` "조건에 맞는 할 일이 없습니다."

  it "여러 할 일은 줄바꿈으로 이어 붙인다" $
    length (T.lines (renderTodoList [sample, sample{todoId = TodoId 2}])) `shouldBe` 2

  it "없는 할 일 오류는 식별자를 알려준다" $
    renderUseCaseError (TodoNotFound (TodoId 9)) `shouldBe` "할 일을 찾을 수 없습니다: 9"

  it "허용되지 않은 전이는 두 상태를 모두 알려준다" $
    renderUseCaseError (InvalidTransition (TodoId 3) (ForbiddenTransition Archived InProgress))
      `shouldBe` "할 일 3을(를) archived에서 in_progress(으)로 바꿀 수 없습니다."
