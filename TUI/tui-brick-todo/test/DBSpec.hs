{-# LANGUAGE OverloadedStrings #-}

module DBSpec ( spec ) where

import           DB
import           Database.SQLite.Simple (open)
import           Flow                   ((<|))
import qualified I18n
import           Test.Hspec

spec :: Spec
spec = do
  describe "TodoRow" <| do
    it "TodoRow는 Eq 인스턴스를 가져야 함" <| do
      let row1 = TodoRow 1 "Test" "registered" "2024-01-01" Nothing Nothing Nothing Nothing
          row2 = TodoRow 1 "Test" "registered" "2024-01-01" Nothing Nothing Nothing Nothing
      row1 `shouldBe` row2

    it "다른 TodoRow는 같지 않아야 함" <| do
      let row1 = TodoRow 1 "Test1" "registered" "2024-01-01" Nothing Nothing Nothing Nothing
          row2 = TodoRow 2 "Test2" "registered" "2024-01-01" Nothing Nothing Nothing Nothing
      row1 `shouldNotBe` row2

  describe "initDB" <| do
    it "데이터베이스를 초기화하고 샘플 데이터를 생성해야 함" <| do
      conn <- open ":memory:"
      initDB conn
      todos <- getAllTodos conn
      length todos `shouldSatisfy` (>= 3)

  describe "initDBWithMessages" <| do
    it "커스텀 메시지로 데이터베이스를 초기화해야 함" <| do
      conn <- open ":memory:"
      initDBWithMessages conn I18n.defaultMessages
      todos <- getAllTodos conn
      length todos `shouldSatisfy` (>= 3)

  describe "createTodo" <| do
    it "새로운 todo를 생성하고 ID를 반환해야 함" <| do
      conn <- open ":memory:"
      initDB conn
      tid <- createTodo conn "New todo"
      tid `shouldSatisfy` (> 0)

    it "생성된 todo가 데이터베이스에 존재해야 함" <| do
      conn <- open ":memory:"
      initDB conn
      newTodoId <- createTodo conn "Test todo"
      todos <- getAllTodos conn
      let createdTodo = head <| filter (\t -> DB.todoId t == newTodoId) todos
      todoAction createdTodo `shouldBe` "Test todo"
      todoStatus createdTodo `shouldBe` "registered"

  describe "createTodoWithFields" <| do
    it "모든 필드를 포함한 todo를 생성해야 함" <| do
      conn <- open ":memory:"
      initDB conn
      newTodoId <- createTodoWithFields conn "Action" (Just "Subject") (Just "Indirect") (Just "Direct")
      todos <- getAllTodos conn
      let createdTodo = head <| filter (\t -> DB.todoId t == newTodoId) todos
      todoAction createdTodo `shouldBe` "Action"
      todoSubject createdTodo `shouldBe` Just "Subject"
      todoIndirectObject createdTodo `shouldBe` Just "Indirect"
      todoDirectObject createdTodo `shouldBe` Just "Direct"

    it "Nothing 필드로 todo를 생성할 수 있어야 함" <| do
      conn <- open ":memory:"
      initDB conn
      newTodoId <- createTodoWithFields conn "Simple" Nothing Nothing Nothing
      todos <- getAllTodos conn
      let createdTodo = head <| filter (\t -> DB.todoId t == newTodoId) todos
      todoSubject createdTodo `shouldBe` Nothing
      todoIndirectObject createdTodo `shouldBe` Nothing
      todoDirectObject createdTodo `shouldBe` Nothing

  describe "getAllTodos" <| do
    it "모든 todos를 ID 역순으로 반환해야 함" <| do
      conn <- open ":memory:"
      initDB conn
      _ <- createTodo conn "First"
      id2 <- createTodo conn "Second"
      todos <- getAllTodos conn
      let ids = map todoId todos
      head ids `shouldSatisfy` (>= id2)

  describe "updateTodoWithFields" <| do
    it "특정 필드만 업데이트해야 함" <| do
      conn <- open ":memory:"
      initDB conn
      newTodoId <- createTodo conn "Original"
      updateTodoWithFields conn newTodoId "Modified" (Just "NewSub") Nothing Nothing
      todos <- getAllTodos conn
      let updated = head <| filter (\t -> DB.todoId t == newTodoId) todos
      todoAction updated `shouldBe` "Modified"
      todoSubject updated `shouldBe` Just "NewSub"

  describe "deleteTodo" <| do
    it "todo를 삭제해야 함" <| do
      conn <- open ":memory:"
      initDB conn
      tid <- createTodo conn "To delete"
      beforeCount <- length <$> getAllTodos conn
      deleteTodo conn tid
      afterCount <- length <$> getAllTodos conn
      afterCount `shouldBe` (beforeCount - 1)

    it "삭제된 todo는 조회되지 않아야 함" <| do
      conn <- open ":memory:"
      initDB conn
      newTodoId <- createTodo conn "To delete"
      deleteTodo conn newTodoId
      todos <- getAllTodos conn
      let found = filter (\t -> DB.todoId t == newTodoId) todos
      found `shouldBe` []

  describe "Status Transitions" <| do
    it "Registered에서 InProgress로 전환해야 함" <| do
      conn <- open ":memory:"
      initDB conn
      newTodoId <- createTodo conn "Status test"
      transitionToInProgress conn newTodoId
      todos <- getAllTodos conn
      let updated = head <| filter (\t -> DB.todoId t == newTodoId) todos
      todoStatus updated `shouldBe` "in_progress"
      todoStatusChangedAt updated `shouldSatisfy` (/= Nothing)

    it "InProgress에서 Cancelled로 전환해야 함" <| do
      conn <- open ":memory:"
      initDB conn
      newTodoId <- createTodo conn "Status test"
      transitionToInProgress conn newTodoId
      transitionToCancelled conn newTodoId
      todos <- getAllTodos conn
      let updated = head <| filter (\t -> DB.todoId t == newTodoId) todos
      todoStatus updated `shouldBe` "cancelled"

    it "Cancelled에서 Completed로 전환해야 함" <| do
      conn <- open ":memory:"
      initDB conn
      newTodoId <- createTodo conn "Status test"
      transitionToInProgress conn newTodoId
      transitionToCancelled conn newTodoId
      transitionToCompleted conn newTodoId
      todos <- getAllTodos conn
      let updated = head <| filter (\t -> DB.todoId t == newTodoId) todos
      todoStatus updated `shouldBe` "completed"

    it "Completed에서 Registered로 전환해야 함" <| do
      conn <- open ":memory:"
      initDB conn
      newTodoId <- createTodo conn "Status test"
      transitionToInProgress conn newTodoId
      transitionToCancelled conn newTodoId
      transitionToCompleted conn newTodoId
      transitionToRegistered conn newTodoId
      todos <- getAllTodos conn
      let updated = head <| filter (\t -> DB.todoId t == newTodoId) todos
      todoStatus updated `shouldBe` "registered"
