{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE UndecidableInstances       #-}

-- | Tagless Final Application Monad and Interpreters
--
-- This module provides the concrete interpreter for all effect algebras.
-- The AppM monad implements all effect type classes defined in Effects module.
module App
    ( AppEnv (..)
    , AppM
    , runAppM
    ) where

import qualified Config

import           Control.Monad.IO.Class (MonadIO, liftIO)
import           Control.Monad.Reader   (MonadReader, ReaderT, asks, runReaderT)

import qualified DB

import qualified Data.Time.Clock        as Time

import           Database.SQLite.Simple (Connection)

import           Effects

import           Flow                   ((<|))

import qualified I18n

-- | Application environment containing dependencies
data AppEnv = AppEnv { envConnection  :: !Connection
                     , envMessages    :: !I18n.I18nMessages
                     , envKeyBindings :: !Config.KeyBindings
                     }

-- | Tagless Final interpreter monad
newtype AppM a = AppM { unAppM :: ReaderT AppEnv IO a }
     deriving (Applicative, Functor, Monad, MonadIO, MonadReader AppEnv)

-- | Run the application monad
runAppM :: AppEnv -> AppM a -> IO a
runAppM env = flip runReaderT env . unAppM

-- | MonadTodoRepo interpreter - Database operations
instance MonadTodoRepo AppM where
    getAllTodos = do
        conn <- asks envConnection
        liftIO <| DB.getAllTodos conn

    createTodo text = do
        conn <- asks envConnection
        liftIO <| DB.createTodo conn text

    createTodoWithFields action subj indObj dirObj = do
        conn <- asks envConnection
        liftIO <| DB.createTodoWithFields conn action subj indObj dirObj

    updateTodoFields tid action subj indObj dirObj = do
        conn <- asks envConnection
        liftIO <| DB.updateTodoWithFields conn tid action subj indObj dirObj

    deleteTodo tid = do
        conn <- asks envConnection
        liftIO <| DB.deleteTodo conn tid

    transitionToInProgress tid = do
        conn <- asks envConnection
        liftIO <| DB.transitionToInProgress conn tid

    transitionToCancelled tid = do
        conn <- asks envConnection
        liftIO <| DB.transitionToCancelled conn tid

    transitionToCompleted tid = do
        conn <- asks envConnection
        liftIO <| DB.transitionToCompleted conn tid

    transitionToRegistered tid = do
        conn <- asks envConnection
        liftIO <| DB.transitionToRegistered conn tid

-- | MonadConfig interpreter - Configuration access
instance MonadConfig AppM where
    getKeyBindings = asks envKeyBindings

-- | MonadI18n interpreter - Internationalization
instance MonadI18n AppM where
    getMessages = asks envMessages

-- | MonadTime interpreter - Time operations
instance MonadTime AppM where
    getCurrentTime = liftIO Time.getCurrentTime
