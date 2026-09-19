{-# LANGUAGE OverloadedStrings #-}

-- | SQLite 어댑터가 'TodoRepository' 계약을 지키는지 검증합니다.
--
-- @src/core/tests@의 가짜 저장소와 같은 계약을 실제 저장 매체에서
-- 다시 확인하는 것이 목적입니다.
module Todo.Store.SqliteSpec (spec) where

import qualified Data.Set as Set
import Data.Time (UTCTime (..), addUTCTime, fromGregorian, secondsToDiffTime)
import Database.SQLite.Simple (Connection)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Hspec (Spec, describe, it, shouldBe, shouldSatisfy)
import Todo.Core.Repository (NewTodo (..), TodoRepository (..))
import Todo.Core.Types (
  ListId (..),
  Priority (..),
  Status (..),
  Tag (..),
  Title (..),
  Todo (..),
  TodoId (..),
 )
import Todo.Core.UseCase (StatusChange (..), completeTodo)
import Todo.Store.Migration (currentSchemaVersion, readSchemaVersion)
import Todo.Store.Sqlite (openStore, runSqlite, withStore)

fixedNow :: UTCTime
fixedNow = UTCTime (fromGregorian 2026 8 22) (secondsToDiffTime 0)

sampleNew :: NewTodo
sampleNew =
  NewTodo
    { newTitle = Title "보고서 작성"
    , newListId = ListId "inbox"
    , newPriority = High
    , newTags = Set.fromList [Tag "work", Tag "deep-work"]
    , newDueOn = Just (fromGregorian 2026 9 1)
    , newCreatedAt = fixedNow
    }

-- | 임시 디렉터리의 새 데이터베이스에서 동작을 실행합니다.
withTempStore :: (Connection -> IO a) -> IO a
withTempStore action =
  withSystemTempDirectory "store-test" $ \dir ->
    withStore (dir </> "todo.db") action

spec :: Spec
spec = describe "Todo.Store.Sqlite" $ do
  it "새 데이터베이스에 현재 스키마 버전을 기록한다" $ do
    version <- withTempStore readSchemaVersion
    version `shouldBe` Just currentSchemaVersion

  it "이미 스키마가 있는 파일을 다시 열어도 안전하다" $
    withSystemTempDirectory "store-reopen" $ \dir -> do
      let path = dir </> "todo.db"
      first <- openStore path
      inserted <- runSqlite first (insertTodo sampleNew)
      second <- openStore path
      found <- runSqlite second (findTodo (todoId inserted))
      fmap todoTitle found `shouldBe` Just (Title "보고서 작성")

  it "저장한 값을 그대로 되읽는다" $ do
    result <- withTempStore $ \conn -> runSqlite conn $ do
      inserted <- insertTodo sampleNew
      findTodo (todoId inserted)
    fmap (\t -> (todoTitle t, todoPriority t, todoDueOn t, todoTags t)) result
      `shouldBe` Just
        ( Title "보고서 작성"
        , High
        , Just (fromGregorian 2026 9 1)
        , Set.fromList [Tag "work", Tag "deep-work"]
        )

  it "새 할 일은 Pending 상태로 저장한다" $ do
    status <- withTempStore $ \conn -> runSqlite conn (todoStatus <$> insertTodo sampleNew)
    status `shouldBe` Pending

  it "서로 다른 할 일에 서로 다른 식별자를 부여한다" $ do
    ids <- withTempStore $ \conn -> runSqlite conn $ do
      a <- insertTodo sampleNew
      b <- insertTodo sampleNew{newTitle = Title "두 번째"}
      pure (todoId a, todoId b)
    ids `shouldSatisfy` uncurry (/=)

  it "없는 할 일 조회는 Nothing이다" $ do
    found <- withTempStore $ \conn -> runSqlite conn (findTodo (TodoId 4242))
    found `shouldBe` Nothing

  it "없는 할 일 갱신은 False를 반환하고 새 행을 만들지 않는다" $ do
    (replaced, count) <- withTempStore $ \conn -> runSqlite conn $ do
      inserted <- insertTodo sampleNew
      ok <- replaceTodo inserted{todoId = TodoId 4242}
      todos <- allTodos
      pure (ok, length todos)
    (replaced, count) `shouldBe` (False, 1)

  it "태그 갱신은 이전 태그를 남기지 않는다" $ do
    tags <- withTempStore $ \conn -> runSqlite conn $ do
      inserted <- insertTodo sampleNew
      _ <- replaceTodo inserted{todoTags = Set.fromList [Tag "home"]}
      found <- findTodo (todoId inserted)
      pure (fmap todoTags found)
    tags `shouldBe` Just (Set.fromList [Tag "home"])

  it "삭제는 태그까지 함께 정리한다" $ do
    (removedFirst, removedAgain, remaining) <- withTempStore $ \conn -> runSqlite conn $ do
      inserted <- insertTodo sampleNew
      first <- removeTodo (todoId inserted)
      again <- removeTodo (todoId inserted)
      todos <- allTodos
      pure (first, again, length todos)
    (removedFirst, removedAgain, remaining) `shouldBe` (True, False, 0)

  it "유스케이스의 멱등 규칙이 실제 저장소에서도 유지된다" $ do
    result <- withTempStore $ \conn -> runSqlite conn $ do
      inserted <- insertTodo sampleNew
      _ <- completeTodo (addUTCTime 60 fixedNow) (todoId inserted)
      completeTodo (addUTCTime 120 fixedNow) (todoId inserted)
    fmap (\c -> (todoStatus (changedTodo c), statusWasChanged c, todoUpdatedAt (changedTodo c))) result
      `shouldBe` Right (Done, False, addUTCTime 60 fixedNow)

  it "목록 조회는 식별자 순서를 유지한다" $ do
    ids <- withTempStore $ \conn -> runSqlite conn $ do
      _ <- insertTodo sampleNew
      _ <- insertTodo sampleNew{newTitle = Title "두 번째"}
      _ <- insertTodo sampleNew{newTitle = Title "세 번째"}
      map todoId <$> allTodos
    ids `shouldBe` [TodoId 1, TodoId 2, TodoId 3]
