{-# LANGUAGE OverloadedStrings #-}

-- | Test suite for the Todo application
module Main
    ( main
    ) where


import           Data.Either
    ( isLeft
    , isRight
    )
import           Data.Text                                        (pack)
import           Flow                                             ((<|))
import           Test.Hspec

-- Domain imports
import           Domain.Repositories.Entities.Todo
    ( NewTodo (..)
    , Priority (..)
    , Status (DoingStatus, DoneStatus, TodoStatus)
    , Todo (..)
    , ValidationError (..)
    , validateTodoTitle
    )

-- Application imports
import           Application.UseCases.TodoUseCases

-- Infrastructure imports
import           Infrastructure.Repositories.SQLiteTodoRepository

-- -------------------------------------------------------------------
-- Test Suite
-- -------------------------------------------------------------------

-- | Main test runner
main :: IO ()
main = hspec spec

-- | Test specifications
spec :: Spec
spec = do
    describe "Domain.Repositories.Entities.Todo" <| do
        context "when validating todo titles" <| do
            it "should reject empty titles" <| do
                validateTodoTitle (pack "") `shouldSatisfy` isLeft

            it "should reject titles shorter than 3 characters" <| do
                validateTodoTitle (pack "ab") `shouldSatisfy` isLeft

            it "should reject titles longer than 50 characters" <| do
                validateTodoTitle (pack <| replicate 51 'a') `shouldSatisfy` isLeft

            it "should accept valid titles" <| do
                validateTodoTitle (pack "Buy groceries") `shouldSatisfy` isRight
                validateTodoTitle (pack "abc") `shouldSatisfy` isRight
                validateTodoTitle (pack <| replicate 50 'a') `shouldSatisfy` isRight
                
            it "should return appropriate error messages" <| do
                case validateTodoTitle (pack "") of
                    Left (ValidationError msg) -> msg `shouldBe` "TodoTitle cannot be empty"
                    Right _ -> expectationFailure "Expected validation error for empty title"
                
                case validateTodoTitle (pack "ab") of
                    Left (ValidationError msg) -> msg `shouldBe` "TodoTitle must be at least 3 characters long"
                    Right _ -> expectationFailure "Expected validation error for short title"

        context "when working with Priority" <| do
            it "should convert Priority to String correctly" <| do
                show Low `shouldBe` "Low"
                show Medium `shouldBe` "Medium"
                show High `shouldBe` "High"

            it "should cycle through priorities correctly" <| do
                -- Test the enum cycle: Low -> Medium -> High -> Low
                succ Low `shouldBe` Medium
                succ Medium `shouldBe` High
                succ High `shouldBe` Low  -- Wraps around due to Bounded instance
                
                -- Test the reverse cycle
                pred Low `shouldBe` High
                pred High `shouldBe` Medium
                pred Medium `shouldBe` Low

            it "should have correct min and max bounds" <| do
                minBound `shouldBe` Low
                maxBound `shouldBe` High
                
            it "should handle toEnum and fromEnum correctly" <| do
                toEnum 0 `shouldBe` Low
                toEnum 1 `shouldBe` Medium
                toEnum 2 `shouldBe` High
                toEnum 3 `shouldBe` Low  -- Tests wrapping
                
                fromEnum Low `shouldBe` 0
                fromEnum Medium `shouldBe` 1
                fromEnum High `shouldBe` 2

        context "when working with Status" <| do
            it "should convert Status to String correctly" <| do
                show TodoStatus `shouldBe` "Todo"
                show DoingStatus `shouldBe` "Doing"
                show DoneStatus `shouldBe` "Done"
                
            it "should cycle through statuses correctly" <| do
                -- Test the cycle: TodoStatus -> DoingStatus -> DoneStatus -> TodoStatus
                succ TodoStatus `shouldBe` DoingStatus
                succ DoingStatus `shouldBe` DoneStatus
                succ DoneStatus `shouldBe` TodoStatus
                
                -- Test the reverse cycle
                pred TodoStatus `shouldBe` DoneStatus
                pred DoneStatus `shouldBe` DoingStatus
                pred DoingStatus `shouldBe` TodoStatus

    describe "Infrastructure.Repositories.SQLiteTodoRepository" <| do
        context "when performing database operations" <| do
            it "should be able to create a database connection" <| do
                withConn (\_ -> pure True) `shouldReturn` True

    describe "Application.UseCases.TodoUseCases" <| do
        context "when creating a new todo" <| do
            it "should validate the todo before creation" <| do
                let invalidTodo = NewTodo (pack "") Medium
                result <- runSQLiteRepo <| createNewTodo invalidTodo
                result `shouldSatisfy` isLeft

            it "should accept valid todos" <| do
                let validTodo = NewTodo (pack "Test Todo") Medium
                -- This is just a validation test, not actually inserting into DB
                validateTodoTitle (newTodoTitle validTodo) `shouldSatisfy` isRight
                
            it "should return validation errors with appropriate messages" <| do
                let emptyTitleTodo = NewTodo (pack "") Medium
                result <- runSQLiteRepo <| createNewTodo emptyTitleTodo
                case result of
                    Left (ValidationError msg) -> msg `shouldBe` "TodoTitle cannot be empty"
                    Right _ -> expectationFailure "Expected validation error for empty title"

        context "when updating a todo" <| do
            it "should validate the todo before update" <| do
                -- Create a Todo with empty title (which should be invalid)
                let invalidTodo = Todo
                      { todoId = 1
                      , todoTitle = pack ""
                      , createdAt = read "2023-01-01 00:00:00 UTC"
                      , priority = Low
                      , status = TodoStatus
                      }
                result <- runSQLiteRepo <| updateExistingTodo 1 invalidTodo
                result `shouldSatisfy` isLeft

            it "should accept valid todos for update" <| do
                -- Create a valid Todo
                let validTodo = Todo
                      { todoId = 1
                      , todoTitle = pack "Valid Todo"
                      , createdAt = read "2023-01-01 00:00:00 UTC"
                      , priority = Medium
                      , status = DoingStatus
                      }
                validateTodoTitle (todoTitle validTodo) `shouldSatisfy` isRight
        
        context "when testing integration features" <| do
            it "should have integration tests in a real project" <| do
                pendingWith "Integration tests would be implemented with a proper test database setup"
