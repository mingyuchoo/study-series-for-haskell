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
createNewTodo :: MonadTodoRepo m
              => String
              -> Maybe String
              -> Maybe String
              -> Maybe String
              -> m DB.TodoId
createNewTodo action subject indirect direct =
    createTodoWithFields
        (strip action)
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

-- | Cycle todo status forward using TodoStatus type-safe definitions
-- Registered → InProgress → Cancelled → Completed → Registered
cycleStatusForward :: MonadTodoRepo m => DB.TodoId -> String -> m ()
cycleStatusForward tid currentStatus
    | currentStatus == TodoStatus.statusToString TodoStatus.StatusRegistered  = transitionToInProgress tid
    | currentStatus == TodoStatus.statusToString TodoStatus.StatusInProgress  = transitionToCancelled tid
    | currentStatus == TodoStatus.statusToString TodoStatus.StatusCancelled   = transitionToCompleted tid
    | currentStatus == TodoStatus.statusToString TodoStatus.StatusCompleted   = transitionToRegistered tid
    | otherwise = pure ()

-- | Strip leading/trailing whitespace and collapse internal spaces (Pure)
strip :: String -> String
strip = unwords . words

-- | Normalize optional field: trim whitespace, convert empty to Nothing (Pure)
normalizeField :: Maybe String -> Maybe String
normalizeField Nothing  = Nothing
normalizeField (Just s) =
    let stripped = strip s
    in if null stripped then Nothing else Just stripped
