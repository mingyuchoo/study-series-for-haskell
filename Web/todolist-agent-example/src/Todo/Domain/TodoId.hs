{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}

module Todo.Domain.TodoId (
    TodoId,
    fromUUID,
    parseTodoId,
    renderTodoId,
    unTodoId,
) where

import Data.Text (Text)
import Data.UUID (UUID)
import Data.UUID qualified as UUID

newtype TodoId = TodoId {unTodoId :: UUID}
    deriving (Eq, Ord)

instance Show TodoId where
    show = show . unTodoId

fromUUID :: UUID -> TodoId
fromUUID = TodoId

parseTodoId :: Text -> Either Text TodoId
parseTodoId raw =
    case UUID.fromText raw of
        Nothing -> Left "Invalid Todo UUID"
        Just value -> Right (TodoId value)

renderTodoId :: TodoId -> Text
renderTodoId = UUID.toText . unTodoId
