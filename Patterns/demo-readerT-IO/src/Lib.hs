{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}

module Lib
    ( someFunc
    ) where

import           Control.Monad.Reader

import           Data.IORef
import           Data.Text            (Text)

import           GHC.Generics         (Generic)

-- | 공통기능 사양
data Todo = Todo { todoId :: Int
                 , title  :: Text
                 }
     deriving (Generic, Show)

-- | ReaderT + IO Pattern
data Env = Env { db :: IORef [Todo]
               }

newtype App a = App { runApp :: ReaderT Env IO a }
     deriving (Applicative, Functor, Monad, MonadIO, MonadReader Env)

addTodo :: Text -> App Todo
addTodo t = do
  ref <- asks db
  liftIO $ do
    todos <- readIORef ref
    let new = Todo (length todos + 1) t
    writeIORef ref (todos ++ [new])
    pure new

listTodos :: App [Todo]
listTodos = do
  ref <- asks db
  liftIO $ readIORef ref

someFunc :: IO ()
someFunc = do
  ref <- newIORef []
  let env = Env ref
  runReaderT (runApp run) env
  where
    run = do
      _ <- addTodo "Buy milk"
      _ <- addTodo "Write Haskell"
      listTodos >>= liftIO . print
