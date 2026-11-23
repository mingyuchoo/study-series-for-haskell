{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module Lib
  ( someFunc
  )
where

import Control.Monad.State
import Data.Text (Text)
import GHC.Generics (Generic)

data Todo = Todo
  { todoId :: Int
  , title :: Text
  }
  deriving (Generic, Show)

newtype App a = App {unApp :: StateT [Todo] IO a}
  deriving (Applicative, Functor, Monad, MonadIO, MonadState [Todo])

class (Monad m) => MonadTodo m where
  addTodo :: Text -> m Todo
  listTodos :: m [Todo]

instance MonadTodo App where
  addTodo t = do
    todos <- get
    let new = Todo (length todos + 1) t
    put (todos ++ [new])
    return new
  listTodos = get

runApp :: App a -> IO a
runApp app = evalStateT (unApp app) []

someFunc :: IO ()
someFunc = runApp $ do
  _ <- addTodo "Buy milk"
  _ <- addTodo "Write Haskell"
  listTodos >>= liftIO . print
