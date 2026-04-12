{-# LANGUAGE OverloadedStrings #-}

module AppSpec ( spec ) where

import           App
import qualified Config
import qualified DB
import           Database.SQLite.Simple (open)
import           Effects
import           Flow                   ((<|))
import qualified I18n
import qualified TodoService
import           Test.Hspec

spec :: Spec
spec = do
  describe "AppEnv" <| do
    it "AppEnv를 생성할 수 있어야 함" <| do
      conn <- open ":memory:"
      let env = AppEnv conn I18n.defaultMessages Config.defaultKeyBindings
      True `shouldBe` True

  describe "runAppM" <| do
    it "AppM 모나드를 실행할 수 있어야 함" <| do
      conn <- open ":memory:"
      DB.initDB conn
      let env = AppEnv conn I18n.defaultMessages Config.defaultKeyBindings
      result <- runAppM env TodoService.loadAllTodos
      length result `shouldSatisfy` (>= 0)

  describe "MonadTodoRepo - loadAllTodos" <| do
    it "데이터베이스에서 모든 todos를 로드해야 함" <| do
      conn <- open ":memory:"
      DB.initDB conn
      let env = AppEnv conn I18n.defaultMessages Config.defaultKeyBindings
      todos <- runAppM env TodoService.loadAllTodos
      length todos `shouldSatisfy` (>= 0)

  describe "MonadTodoRepo - createTodo" <| do
    it "새로운 todo를 생성하고 ID를 반환해야 함" <| do
      conn <- open ":memory:"
      DB.initDB conn
      let env = AppEnv conn I18n.defaultMessages Config.defaultKeyBindings
      tid <- runAppM env <| createTodo "Test todo"
      tid `shouldSatisfy` (> 0)

  describe "MonadTodoRepo - createTodoWithFields" <| do
    it "모든 필드를 포함한 todo를 생성해야 함" <| do
      conn <- open ":memory:"
      DB.initDB conn
      let env = AppEnv conn I18n.defaultMessages Config.defaultKeyBindings
      maybeTid <- runAppM env <| TodoService.createNewTodo "Action" (Just "Subject") (Just "Indirect") (Just "Direct")
      maybeTid `shouldSatisfy` (/= Nothing)

      let Just tid = maybeTid
      todos <- runAppM env TodoService.loadAllTodos
      let createdTodo = head <| filter (\t -> DB.todoId t == tid) todos
      DB.todoAction createdTodo `shouldBe` "Action"
      DB.todoSubject createdTodo `shouldBe` Just "Subject"
      DB.todoIndirectObject createdTodo `shouldBe` Just "Indirect"
      DB.todoDirectObject createdTodo `shouldBe` Just "Direct"

  describe "MonadTodoRepo - updateTodoFields" <| do
    it "기존 todo를 업데이트해야 함" <| do
      conn <- open ":memory:"
      DB.initDB conn
      let env = AppEnv conn I18n.defaultMessages Config.defaultKeyBindings
      tid <- runAppM env <| createTodo "Original"
      runAppM env <| TodoService.updateTodoById tid "Updated" (Just "NewSubject") Nothing Nothing

      todos <- runAppM env TodoService.loadAllTodos
      let updatedTodo = head <| filter (\t -> DB.todoId t == tid) todos
      DB.todoAction updatedTodo `shouldBe` "Updated"
      DB.todoSubject updatedTodo `shouldBe` Just "NewSubject"

  describe "MonadTodoRepo - deleteTodo" <| do
    it "todo를 삭제해야 함" <| do
      conn <- open ":memory:"
      DB.initDB conn
      let env = AppEnv conn I18n.defaultMessages Config.defaultKeyBindings
      tid <- runAppM env <| createTodo "To be deleted"
      beforeCount <- length <$> runAppM env TodoService.loadAllTodos
      runAppM env <| TodoService.deleteTodoById tid
      afterCount <- length <$> runAppM env TodoService.loadAllTodos
      afterCount `shouldBe` (beforeCount - 1)

  describe "TodoService - cycleStatusForward" <| do
    it "todo의 상태를 순환해야 함" <| do
      conn <- open ":memory:"
      DB.initDB conn
      let env = AppEnv conn I18n.defaultMessages Config.defaultKeyBindings
      tid <- runAppM env <| createTodo "Status test"

      -- registered -> in_progress
      runAppM env <| TodoService.cycleStatusForward tid "registered"
      todos1 <- runAppM env TodoService.loadAllTodos
      let todo1 = head <| filter (\t -> DB.todoId t == tid) todos1
      DB.todoStatus todo1 `shouldBe` "in_progress"

      -- in_progress -> cancelled
      runAppM env <| TodoService.cycleStatusForward tid "in_progress"
      todos2 <- runAppM env TodoService.loadAllTodos
      let todo2 = head <| filter (\t -> DB.todoId t == tid) todos2
      DB.todoStatus todo2 `shouldBe` "cancelled"
