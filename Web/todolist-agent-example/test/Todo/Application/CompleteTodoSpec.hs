{-# LANGUAGE OverloadedStrings #-}

module Todo.Application.CompleteTodoSpec (spec) where

import Support.Fixtures (fixedTime, fixedTodoId, laterTime, newInMemoryRepository)
import Test.Hspec (Spec, describe, it, shouldBe)
import Todo.Application.CompleteTodo qualified as Complete
import Todo.Application.CreateTodo qualified as Create
import Todo.Domain.Todo (todoCompletedAt)

spec :: Spec
spec = describe "CompleteTodo.execute" $ do
    it "preserves the original timestamp when completion is retried" $ do
        repo <- newInMemoryRepository
        let createDeps = Create.CreateTodoDependencies repo (pure fixedTodoId) (pure fixedTime)
        created <- Create.execute createDeps (Create.CreateTodoCommand "Buy milk" Nothing)
        case created of
            Left err -> fail (show err)
            Right _ -> do
                first <- Complete.execute (Complete.CompleteTodoDependencies repo (pure fixedTime)) fixedTodoId
                second <- Complete.execute (Complete.CompleteTodoDependencies repo (pure laterTime)) fixedTodoId
                case (first, second) of
                    (Right firstTodo, Right secondTodo) -> do
                        todoCompletedAt firstTodo `shouldBe` Just fixedTime
                        todoCompletedAt secondTodo `shouldBe` Just fixedTime
                    other -> fail ("unexpected result: " <> show other)
