-- | Application use cases for Todo operations
module Application.UseCases.TodoUseCases
  ( -- * Use cases
    createNewTodo
  , getTodo
  , getTodoList
  , removeTodo
  , updateExistingTodo
    -- * Re-exports
  , TodoRepository (getAllTodos, getTodoById, createTodo, updateTodo, deleteTodo)
  ) where

-- -------------------------------------------------------------------
-- Imports
-- -------------------------------------------------------------------

import Domain.Repositories.Entities.Todo (NewTodo, Todo, ValidationError)
import Domain.Repositories.TodoRepository
  ( TodoRepository (..)
  , createTodo
  , deleteTodo
  , getAllTodos
  , getTodoById
  , updateTodo
  )

-- -------------------------------------------------------------------
-- Use cases for Todo operations
-- -------------------------------------------------------------------

-- | Get all todos in the system
--
-- This is a simple pass-through to the repository layer
getTodoList :: (TodoRepository m) => m [Todo]
getTodoList = getAllTodos

-- | Get a specific todo by ID
--
-- Returns an empty list if the todo doesn't exist
getTodo :: (TodoRepository m) => Int -> m [Todo]
getTodo = getTodoById

-- | Create a new todo with validation
--
-- The validation is performed at the repository layer
createNewTodo :: (TodoRepository m) => NewTodo -> m (Either ValidationError [Todo])
createNewTodo = createTodo

-- | Update an existing todo with validation
--
-- The validation is performed at the repository layer
updateExistingTodo :: (TodoRepository m) => Int -> Todo -> m (Either ValidationError [Todo])
updateExistingTodo = updateTodo

-- | Remove a todo by ID
--
-- Returns the deleted todo before removal
removeTodo :: (TodoRepository m) => Int -> m [Todo]
removeTodo = deleteTodo
