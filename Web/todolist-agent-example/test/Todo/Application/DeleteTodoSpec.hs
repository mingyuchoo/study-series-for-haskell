{-# LANGUAGE OverloadedStrings #-}

module Todo.Application.DeleteTodoSpec (spec) where

import Support.Fixtures (fixedTime, fixedTodoId, newInMemoryRepository)
import Test.Hspec (Spec, describe, it, shouldBe)
import Todo.Application.CreateTodo qualified as Create
import Todo.Application.DeleteTodo qualified as Delete
import Todo.Application.TodoRepository (TodoRepository (..))

spec :: Spec
spec = describe "DeleteTodo.execute" $ do
    it "deletes an existing Todo" $ do
        repo <- newInMemoryRepository
        let createDeps = Create.CreateTodoDependencies repo (pure fixedTodoId) (pure fixedTime)
        _ <- Create.execute createDeps (Create.CreateTodoCommand "Buy milk" Nothing)
        result <- Delete.execute repo fixedTodoId
        result `shouldBe` Right ()
        stored <- findTodoById repo fixedTodoId
        stored `shouldBe` Right Nothing

    it "reports a missing Todo" $ do
        repo <- newInMemoryRepository
        result <- Delete.execute repo fixedTodoId
        result `shouldBe` Left Delete.DeleteTodoNotFound
