{-# LANGUAGE OverloadedStrings #-}

module Todo.Domain.TodoSpec (spec) where

import Data.Text qualified as Text
import Support.Fixtures (fixedTime, fixedTodoId, laterTime)
import Test.Hspec (Spec, describe, it, shouldBe, shouldSatisfy)
import Todo.Domain.Todo (
    TodoStatus (..),
    TodoTitleError (..),
    completeTodo,
    createTodo,
    mkTodoTitle,
    todoCompletedAt,
    todoStatus,
 )

spec :: Spec
spec = do
    describe "mkTodoTitle" $ do
        it "accepts and trims a valid title" $ do
            mkTodoTitle "  Buy milk  " `shouldSatisfy` isRight
        it "rejects whitespace-only titles" $ do
            mkTodoTitle "   \n\t" `shouldBe` Left EmptyTodoTitle
        it "rejects titles longer than 200 characters" $ do
            mkTodoTitle (Text.replicate 201 "x") `shouldBe` Left TodoTitleTooLong

    describe "completeTodo" $ do
        it "is idempotent and preserves the first completion timestamp" $ do
            case mkTodoTitle "Buy milk" of
                Left err -> fail (show err)
                Right title -> do
                    let original = createTodo fixedTodoId fixedTime title Nothing
                        once = completeTodo fixedTime original
                        twice = completeTodo laterTime once
                    todoStatus twice `shouldBe` Completed
                    todoCompletedAt twice `shouldBe` Just fixedTime
  where
    isRight (Right _) = True
    isRight _ = False
