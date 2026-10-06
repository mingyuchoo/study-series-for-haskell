{-# LANGUAGE FlexibleContexts #-}

-- | Tagless Final Effect Type Classes
--
-- This module defines the effect algebras for the application.
-- All business logic should depend on these type classes, not concrete implementations.
--
-- Effects:
--   - MonadTodoRepo: Database operations for todos
--   - MonadConfig: Configuration access
--   - MonadI18n: Internationalization messages
--   - MonadTime: Time operations
module Effects
    ( MonadConfig (..)
    , MonadI18n (..)
    , MonadTime (..)
    , MonadTodoRepo (..)
    ) where

import qualified Config

import qualified DB

import           Data.Time.Clock (UTCTime)

import qualified I18n

-- | Effect algebra for Todo repository operations
class Monad m => MonadTodoRepo m where
    getAllTodos :: m [DB.TodoRow]
    createTodo :: String -> m DB.TodoId
    createTodoWithFields :: String -> Maybe String -> Maybe String -> Maybe String -> m DB.TodoId
    updateTodoFields :: DB.TodoId -> String -> Maybe String -> Maybe String -> Maybe String -> m ()
    deleteTodo :: DB.TodoId -> m ()
    transitionToInProgress :: DB.TodoId -> m ()
    transitionToCancelled :: DB.TodoId -> m ()
    transitionToCompleted :: DB.TodoId -> m ()
    transitionToRegistered :: DB.TodoId -> m ()

-- | Effect algebra for configuration access
class Monad m => MonadConfig m where
    getKeyBindings :: m Config.KeyBindings

-- | Effect algebra for internationalization
class Monad m => MonadI18n m where
    getMessages :: m I18n.I18nMessages

-- | Effect algebra for time operations
class Monad m => MonadTime m where
    getCurrentTime :: m UTCTime
