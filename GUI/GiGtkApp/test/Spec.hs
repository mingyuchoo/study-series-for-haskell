{-# LANGUAGE OverloadedStrings #-}

module Main
    ( main
    ) where

import           Data.Time             (UTCTime, defaultTimeLocale, parseTimeOrError)

import           GiGtkApp.Domain.Todo

main :: IO ()
main = do
    firstTodo <- singleTodo "addTodo" $
        addTodo 1 "  Write Haskell Todo app  " sampleTime []
    updatedTodo <- singleTodo "updateTodoStatus" $
        updateTodoStatus 1 Done changedTime [firstTodo]

    assertEqual "new todo starts pending"
        Pending
        (todoStatus firstTodo)
    assertEqual "new todo stores created time"
        sampleTime
        (todoCreatedAt firstTodo)
    assertEqual "status update changes timestamp"
        changedTime
        (todoStatusChangedAt updatedTodo)
    assertEqual "pending filter hides completed todo"
        []
        (filterTodos OnlyPending [updatedTodo])
    assertEqual "delete removes todo"
        []
        (deleteTodo 1 [updatedTodo])

sampleTime :: UTCTime
sampleTime =
    parseTimeOrError True defaultTimeLocale "%Y-%m-%d %H:%M:%S"
        "2026-06-14 09:00:00"

changedTime :: UTCTime
changedTime =
    parseTimeOrError True defaultTimeLocale "%Y-%m-%d %H:%M:%S"
        "2026-06-14 10:00:00"

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual label expected actual =
    if expected == actual
        then putStrLn (label ++ ": passed")
        else fail (label ++ ": expected " ++ show expected ++ ", got " ++ show actual)

singleTodo :: String -> [TodoItem] -> IO TodoItem
singleTodo _ [todo] = return todo
singleTodo label todos =
    fail (label ++ ": expected one todo, got " ++ show (length todos))
