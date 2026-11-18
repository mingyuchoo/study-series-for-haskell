{-# LANGUAGE OverloadedStrings #-}

module Todo.Infrastructure.Persistence.TodoRepository (
    statusToDatabase,
    statusFromDatabase,
) where

import Data.Text (Text)
import Todo.Application.TodoRepository (RepositoryError (..))
import Todo.Domain.Todo (TodoStatus (..))

statusToDatabase :: TodoStatus -> Text
statusToDatabase Active = "ACTIVE"
statusToDatabase Completed = "COMPLETED"

statusFromDatabase :: Text -> Either RepositoryError TodoStatus
statusFromDatabase "ACTIVE" = Right Active
statusFromDatabase "COMPLETED" = Right Completed
statusFromDatabase other = Left (RepositoryError ("Unknown Todo status in database: " <> other))
