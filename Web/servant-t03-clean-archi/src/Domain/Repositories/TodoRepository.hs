-- | Repository interface for Todo operations
module Domain.Repositories.TodoRepository
  ( -- * Repository interface
    TodoRepository (..)
    -- * Re-export domain entities
  , module Domain.Repositories.Entities.Todo
  ) where

-- -------------------------------------------------------------------
-- Imports
-- -------------------------------------------------------------------

import Domain.Repositories.Entities.Todo

-- -------------------------------------------------------------------
-- Repository Interface
-- -------------------------------------------------------------------

-- | Repository interface defining operations that can be performed on Todo entities
class (Monad m) => TodoRepository m where
  -- | Retrieve all todos
  getAllTodos :: m [Todo]

  -- | Retrieve a specific todo by ID
  -- Returns an empty list if not found
  getTodoById :: Int -> m [Todo]

  -- | Create a new todo
  -- Returns either a validation error or the list of todos including the new one
  createTodo :: NewTodo -> m (Either ValidationError [Todo])

  -- | Update an existing todo
  -- Returns either a validation error or the list of todos including the updated one
  updateTodo :: Int -> Todo -> m (Either ValidationError [Todo])

  -- | Delete a todo by ID
  -- Returns the deleted todo before removal
  deleteTodo :: Int -> m [Todo]
