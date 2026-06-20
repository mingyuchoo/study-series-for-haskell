{-# LANGUAGE DeriveFunctor     #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE GADTs             #-}
{-# LANGUAGE OverloadedStrings #-}

module Lib
    ( someFunc
    ) where

import           Control.Monad.Free

import           Data.IORef
import           Data.Text          (Text)

import           GHC.Generics       (Generic)

data Todo = Todo { todoId :: Int
                 , title  :: Text
                 }
     deriving (Generic, Show)

data TodoF next where AddTodo :: Text -> (Todo -> next) -> TodoF next
                      ListTodos :: ([Todo] -> next) -> TodoF next

instance Functor TodoF where
  fmap f (AddTodo t next) = AddTodo t (f . next)
  fmap f (ListTodos next) = ListTodos (f . next)

type TodoM = Free TodoF

addTodoF :: Text -> TodoM Todo
addTodoF t = liftF (AddTodo t id)

listTodoF :: TodoM [Todo]
listTodoF = liftF (ListTodos id)

-- 프로그램 (순수한 DSL)
program :: TodoM [Todo]
program = do
  _ <- addTodoF "Learn Free Monad"
  listTodoF

-- Interpreter
runIO :: IORef [Todo] -> TodoM a -> IO a
runIO ref = iterM step
  where
    step (AddTodo t next) = do
      xs <- readIORef ref
      let new = Todo (length xs + 1) t
      writeIORef ref (xs ++ [new])
      next new
    step (ListTodos next) = do
      xs <- readIORef ref
      next xs

someFunc :: IO ()
someFunc = do
  ref <- newIORef []
  runIO ref program >>= print
