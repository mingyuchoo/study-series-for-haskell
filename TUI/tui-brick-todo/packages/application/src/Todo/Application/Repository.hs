module Todo.Application.Repository
  ( Repository (..)
  , runCommand
  ) where

import Todo.Application.Types
import Todo.Domain.Model (Todo, TodoFields, TodoId)
import TodoStatus (TodoStatusType)

data Repository m = Repository
  { fetchTodos :: m (Either WorkflowError [Todo])
  , insertTodo :: TodoFields -> m (Either WorkflowError Todo)
  , updateFields :: TodoId -> TodoFields -> m (Either WorkflowError Todo)
  , removeTodo :: TodoId -> m (Either WorkflowError ())
  , setStatus :: TodoId -> TodoStatusType -> TodoStatusType -> m (Either WorkflowError Todo)
  }

runCommand :: (Functor m) => Repository m -> Command -> m Event
runCommand repository command = case command of
  LoadTodos -> result TodosLoaded <$> fetchTodos repository
  InsertTodo value -> result TodoCreated <$> insertTodo repository value
  UpdateFields target value -> result TodoUpdated <$> updateFields repository target value
  RemoveTodo target -> result (const $ TodoDeleted target) <$> removeTodo repository target
  SetStatus target before after -> result StatusChanged <$> setStatus repository target before after
  where
    result constructor = either Rejected (Succeeded . constructor)
