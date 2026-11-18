{-# LANGUAGE OverloadedStrings #-}

module Todo.Application.CreateTodoSpec (spec) where

import Support.Fixtures (fixedTime, fixedTodoId, newInMemoryRepository)
import Test.Hspec (Spec, describe, it, shouldBe)
import Todo.Application.CreateTodo qualified as Create
import Todo.Application.TodoRepository (TodoRepository (..))
import Todo.Domain.Todo (TodoStatus (..), todoStatus)

spec :: Spec
spec = describe "CreateTodo.execute" $ do
    it "persists a valid active Todo" $ do
        repo <- newInMemoryRepository
        let deps = Create.CreateTodoDependencies repo (pure fixedTodoId) (pure fixedTime)
        result <- Create.execute deps (Create.CreateTodoCommand "Buy milk" Nothing)
        case result of
            Left err -> fail (show err)
            Right todo -> do
                todoStatus todo `shouldBe` Active
                stored <- findTodoById repo fixedTodoId
                stored `shouldBe` Right (Just todo)

    it "rejects a blank title without persisting" $ do
        repo <- newInMemoryRepository
        let deps = Create.CreateTodoDependencies repo (pure fixedTodoId) (pure fixedTime)
        result <- Create.execute deps (Create.CreateTodoCommand "   " Nothing)
        case result of
            Left (Create.InvalidTodoTitle _) -> pure ()
            other -> fail ("unexpected result: " <> show other)
        stored <- listAllTodos repo
        stored `shouldBe` Right []
