{-# LANGUAGE FlexibleContexts #-}

-- | Todo Business Logic (Pure with Tagless Final)
--
-- This module contains business logic that depends only on effect algebras.
-- All functions are polymorphic over the monad, enabling easy testing.
--
-- Responsibilities:
--   - Input normalization (trim, empty string → Nothing)
--   - Status cycle logic using type-safe TodoStatus
--   - Pure lookup operations
module TodoService
    ( createNewTodo
    , cycleStatusForward
    , deleteTodoById
    , findTodoById
    , loadAllTodos
    , normalizeField
    , strip
    , updateTodoById
    ) where

import qualified DB

import           Data.List  (find)

import           Effects

import qualified TodoStatus

-- | Load all todos from repository
loadAllTodos :: MonadTodoRepo m => m [DB.TodoRow]
loadAllTodos = getAllTodos

-- | Create a new todo with normalized fields
-- 빈 action은 허용하지 않음 (Nothing 반환)
createNewTodo :: MonadTodoRepo m
              => String
              -> Maybe String
              -> Maybe String
              -> Maybe String
              -> m (Maybe DB.TodoId)
createNewTodo action subject indirect direct =
    let stripped = strip action
    in if null stripped
        then pure Nothing
        else fmap Just $ createTodoWithFields
            stripped
            (normalizeField subject)
            (normalizeField indirect)
            (normalizeField direct)

-- | Update an existing todo with normalized fields
updateTodoById :: MonadTodoRepo m
               => DB.TodoId
               -> String
               -> Maybe String
               -> Maybe String
               -> Maybe String
               -> m ()
updateTodoById tid action subject indirect direct =
    updateTodoFields tid
        (strip action)
        (normalizeField subject)
        (normalizeField indirect)
        (normalizeField direct)

-- | Delete a todo by ID
deleteTodoById :: MonadTodoRepo m => DB.TodoId -> m ()
deleteTodoById = deleteTodo

-- | Find a todo by ID from a list (Pure)
findTodoById :: DB.TodoId -> [DB.TodoRow] -> Maybe DB.TodoRow
findTodoById tid = find (\row -> DB.todoId row == tid)

-- | Cycle todo status forward using type-safe AnyStatus dispatch
-- Registered → InProgress → Cancelled → Completed → Registered
cycleStatusForward :: MonadTodoRepo m => DB.TodoId -> String -> m ()
cycleStatusForward tid currentStatus =
    case TodoStatus.stringToStatus currentStatus of
        Nothing -> pure ()
        Just (TodoStatus.AnyStatus s) -> dispatchTransition tid s

-- | GADT 패턴 매칭을 통한 타입 안전한 상태 전이 디스패치
dispatchTransition :: MonadTodoRepo m => DB.TodoId -> TodoStatus.TodoStatus a -> m ()
dispatchTransition tid TodoStatus.StatusRegistered = transitionToInProgress tid
dispatchTransition tid TodoStatus.StatusInProgress = transitionToCancelled tid
dispatchTransition tid TodoStatus.StatusCancelled  = transitionToCompleted tid
dispatchTransition tid TodoStatus.StatusCompleted  = transitionToRegistered tid

-- | Strip leading/trailing whitespace and collapse internal spaces (Pure)
strip :: String -> String
strip = unwords . words

-- | Normalize optional field: trim whitespace, convert empty to Nothing (Pure)
normalizeField :: Maybe String -> Maybe String
normalizeField Nothing  = Nothing
normalizeField (Just s) =
    let stripped = strip s
    in if null stripped then Nothing else Just stripped
