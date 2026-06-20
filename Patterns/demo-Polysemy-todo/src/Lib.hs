{-# LANGUAGE BlockArguments    #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell   #-}

module Lib
    ( someFunc
    ) where

import           Data.Text      (Text)

import           GHC.Generics   (Generic)

import           Polysemy
import           Polysemy.State

data Todo = Todo { todoId :: Int
                 , title  :: Text
                 }
     deriving (Generic, Show)

data TodoEffect m a where AddTodo :: Text -> TodoEffect m Todo
                          ListTodos :: TodoEffect m [Todo]

makeSem ''TodoEffect

runTodoIO :: (Member (State [Todo]) r) => Sem (TodoEffect : r) a -> Sem r a
runTodoIO = interpret \case
  AddTodo t -> do
    todos <- get
    let new = Todo (length todos + 1) t
    put (todos ++ [new])
    return new
  ListTodos -> get

program :: (Members '[TodoEffect] r) => Sem r [Todo]
program = do
  _ <- addTodo "Polysemy 1"
  _ <- addTodo "Polysemy 2"
  listTodos

someFunc :: IO ()
someFunc = do
  result <- runM . evalState ([] :: [Todo]) . runTodoIO $ program
  print result
