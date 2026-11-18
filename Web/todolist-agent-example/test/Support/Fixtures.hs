{-# LANGUAGE OverloadedStrings #-}

module Support.Fixtures (
    newInMemoryRepository,
    fixedTodoId,
    fixedTime,
    laterTime,
) where

import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.List (sortOn)
import Data.Map.Strict qualified as Map
import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import Todo.Application.TodoRepository (TodoRepository (..))
import Todo.Domain.Todo (Todo, todoCreatedAt, todoId)
import Todo.Domain.TodoId (TodoId, parseTodoId)

newInMemoryRepository :: IO (TodoRepository IO)
newInMemoryRepository = do
    ref <- newIORef Map.empty
    pure (repository ref)
  where
    repository :: IORef (Map.Map TodoId Todo) -> TodoRepository IO
    repository ref =
        TodoRepository
            { insertTodo = \todo -> do
                atomicModifyIORef' ref (\items -> (Map.insert (todoId todo) todo items, ()))
                pure (Right ())
            , findTodoById = \ident -> Right . Map.lookup ident <$> readIORef ref
            , listAllTodos = Right . sortOn todoCreatedAt . Map.elems <$> readIORef ref
            , saveTodo = \todo -> do
                atomicModifyIORef' ref (\items -> (Map.insert (todoId todo) todo items, ()))
                pure (Right ())
            , deleteTodoById = \ident -> do
                existed <- atomicModifyIORef' ref $ \items ->
                    let present = Map.member ident items
                     in (Map.delete ident items, present)
                pure (Right existed)
            }

fixedTodoId :: TodoId
fixedTodoId =
    case parseTodoId "550e8400-e29b-41d4-a716-446655440000" of
        Left err -> error (show err)
        Right value -> value

fixedTime :: UTCTime
fixedTime = UTCTime (fromGregorian 2026 9 9) (secondsToDiffTime 0)

laterTime :: UTCTime
laterTime = UTCTime (fromGregorian 2026 9 10) (secondsToDiffTime 0)
