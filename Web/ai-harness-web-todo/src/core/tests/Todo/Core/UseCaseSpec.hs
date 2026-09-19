{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}

-- | 유스케이스 검증입니다.
--
-- 저장 포트를 순수한 'State' 기반 가짜 구현으로 대체합니다. 실제 SQLite 어댑터가
-- 같은 계약을 지키는지는 @src/store/tests@에서 검증합니다.
module Todo.Core.UseCaseSpec (spec) where

import Control.Monad.State.Strict (State, evalState, gets, modify')
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Time (addUTCTime)
import Test.Hspec (Spec, describe, it, shouldBe)
import Todo.Core.Filter (SortOrder (..), emptyFilter)
import Todo.Core.Gen (fixedNow)
import Todo.Core.Repository (
  NewTodo (..),
  TodoRepository (..),
  emptyPatch,
  patchTitle,
 )
import Todo.Core.Status (TransitionError (..))
import Todo.Core.Types (
  ListId (..),
  Priority (..),
  Status (..),
  Title (..),
  Todo (..),
  TodoId (..),
 )
import Todo.Core.UseCase (
  StatusChange (..),
  UseCaseError (..),
  addTodo,
  archiveTodo,
  completeTodo,
  deleteTodo,
  getTodo,
  listTodos,
  startTodo,
  updateTodo,
 )

-- 순수 가짜 저장소 -----------------------------------------------------------

data StoreState = StoreState
  { storeNextId :: Int
  , storeTodos :: Map Int Todo
  }

newtype FakeStore a = FakeStore (State StoreState a)
  deriving newtype (Functor, Applicative, Monad)

runFake :: FakeStore a -> a
runFake (FakeStore action) = evalState action (StoreState 1 Map.empty)

liftFake :: State StoreState a -> FakeStore a
liftFake = FakeStore

instance TodoRepository FakeStore where
  insertTodo new = liftFake $ do
    nextId <- gets storeNextId
    let todo =
          Todo
            { todoId = TodoId nextId
            , todoTitle = newTitle new
            , todoListId = newListId new
            , todoStatus = Pending
            , todoPriority = newPriority new
            , todoTags = newTags new
            , todoDueOn = newDueOn new
            , todoCreatedAt = newCreatedAt new
            , todoUpdatedAt = newCreatedAt new
            }
    modify' $ \s ->
      s
        { storeNextId = nextId + 1
        , storeTodos = Map.insert nextId todo (storeTodos s)
        }
    pure todo

  findTodo (TodoId tid) = liftFake (gets (Map.lookup tid . storeTodos))

  allTodos = liftFake (gets (Map.elems . storeTodos))

  replaceTodo todo = liftFake $ do
    let TodoId tid = todoId todo
    exists <- gets (Map.member tid . storeTodos)
    if exists
      then do
        modify' $ \s -> s{storeTodos = Map.insert tid todo (storeTodos s)}
        pure True
      else pure False

  removeTodo (TodoId tid) = liftFake $ do
    exists <- gets (Map.member tid . storeTodos)
    modify' $ \s -> s{storeTodos = Map.delete tid (storeTodos s)}
    pure exists

sampleNew :: NewTodo
sampleNew =
  NewTodo
    { newTitle = Title "보고서 작성"
    , newListId = ListId "inbox"
    , newPriority = Normal
    , newTags = Set.empty
    , newDueOn = Nothing
    , newCreatedAt = fixedNow
    }

spec :: Spec
spec = describe "Todo.Core.UseCase" $ do
  it "추가한 할 일은 Pending 상태로 시작한다" $
    runFake (todoStatus <$> addTodo sampleNew) `shouldBe` Pending

  it "추가한 할 일에 식별자를 부여한다" $
    runFake (todoId <$> addTodo sampleNew) `shouldBe` TodoId 1

  it "없는 할 일 조회는 TodoNotFound를 반환한다" $
    runFake (getTodo (TodoId 99)) `shouldBe` Left (TodoNotFound (TodoId 99))

  it "완료 처리는 상태와 변경 시각을 갱신한다" $
    let later = addUTCTime 60 fixedNow
        result = runFake $ do
          todo <- addTodo sampleNew
          completeTodo later (todoId todo)
     in fmap (\c -> (todoStatus (changedTodo c), todoUpdatedAt (changedTodo c), statusWasChanged c)) result
          `shouldBe` Right (Done, later, True)

  it "같은 완료 요청을 두 번 보내도 한 번의 효과만 남는다" $
    let later = addUTCTime 60 fixedNow
        evenLater = addUTCTime 120 fixedNow
        result = runFake $ do
          todo <- addTodo sampleNew
          _ <- completeTodo later (todoId todo)
          completeTodo evenLater (todoId todo)
     in fmap (\c -> (statusWasChanged c, todoUpdatedAt (changedTodo c))) result
          `shouldBe` Right (False, later)

  it "보관한 할 일은 다시 진행 중으로 만들 수 없다" $
    let result = runFake $ do
          todo <- addTodo sampleNew
          _ <- archiveTodo fixedNow (todoId todo)
          startTodo fixedNow (todoId todo)
     in result
          `shouldBe` Left
            (InvalidTransition (TodoId 1) (ForbiddenTransition Archived InProgress))

  it "부분 수정은 지정하지 않은 필드를 보존한다" $
    let patch = emptyPatch{patchTitle = Just (Title "수정한 제목")}
        result = runFake $ do
          todo <- addTodo sampleNew
          updateTodo fixedNow patch (todoId todo)
     in fmap (\t -> (todoTitle t, todoPriority t, todoListId t)) result
          `shouldBe` Right (Title "수정한 제목", Normal, ListId "inbox")

  it "삭제한 할 일은 다시 삭제할 수 없다" $
    let result = runFake $ do
          todo <- addTodo sampleNew
          _ <- deleteTodo (todoId todo)
          deleteTodo (todoId todo)
     in result `shouldBe` Left (TodoNotFound (TodoId 1))

  it "목록 조회는 저장된 할 일을 모두 돌려준다" $
    let result = runFake $ do
          _ <- addTodo sampleNew
          _ <- addTodo sampleNew{newTitle = Title "두 번째"}
          listTodos emptyFilter ByCreatedAt
     in map todoId result `shouldBe` [TodoId 1, TodoId 2]
