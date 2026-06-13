{-# LANGUAGE OverloadedStrings #-}

module GiGtkApp.Domain.Todo
    ( TodoFilter (..)
    , TodoItem (..)
    , TodoStatus (..)
    , addTodo
    , deleteTodo
    , filterTodos
    , statusLabel
    , updateTodoStatus
    , updateTodoTitle
    ) where

import           Data.Text (Text)
import qualified Data.Text as Text
import           Data.Time (UTCTime)

data TodoStatus
    = Pending
    | InProgress
    | Done
    deriving (Eq, Show)

data TodoFilter
    = AllTodos
    | OnlyPending
    | OnlyInProgress
    | OnlyDone
    deriving (Eq, Show)

data TodoItem = TodoItem
    { todoId              :: Int
    , todoTitle           :: Text
    , todoStatus          :: TodoStatus
    , todoCreatedAt       :: UTCTime
    , todoStatusChangedAt :: UTCTime
    }
    deriving (Eq, Show)

addTodo :: Int -> Text -> UTCTime -> [TodoItem] -> [TodoItem]
addTodo newId title now todos =
    todos
        ++ [ TodoItem
                 { todoId = newId
                 , todoTitle = Text.strip title
                 , todoStatus = Pending
                 , todoCreatedAt = now
                 , todoStatusChangedAt = now
                 }
           ]

updateTodoTitle :: Int -> Text -> [TodoItem] -> [TodoItem]
updateTodoTitle targetId newTitle =
    map updateTitle
  where
    updateTitle todo
        | todoId todo == targetId = todo { todoTitle = Text.strip newTitle }
        | otherwise = todo

updateTodoStatus :: Int -> TodoStatus -> UTCTime -> [TodoItem] -> [TodoItem]
updateTodoStatus targetId newStatus now =
    map updateStatus
  where
    updateStatus todo
        | todoId todo /= targetId = todo
        | todoStatus todo == newStatus = todo
        | otherwise = todo
            { todoStatus = newStatus
            , todoStatusChangedAt = now
            }

deleteTodo :: Int -> [TodoItem] -> [TodoItem]
deleteTodo targetId =
    filter ((/= targetId) . todoId)

filterTodos :: TodoFilter -> [TodoItem] -> [TodoItem]
filterTodos AllTodos = id
filterTodos OnlyPending = filter ((== Pending) . todoStatus)
filterTodos OnlyInProgress = filter ((== InProgress) . todoStatus)
filterTodos OnlyDone = filter ((== Done) . todoStatus)

statusLabel :: TodoStatus -> Text
statusLabel Pending    = "대기"
statusLabel InProgress = "진행"
statusLabel Done       = "완료"
