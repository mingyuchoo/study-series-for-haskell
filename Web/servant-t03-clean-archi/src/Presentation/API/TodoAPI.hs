{-# LANGUAGE DataKinds     #-}
{-# LANGUAGE TypeOperators #-}

-- | REST API for Todo operations
module Presentation.API.TodoAPI
  ( -- * API Type
    TodoAPI
    -- * Server Implementation
  , todoServer
  ) where

-- -------------------------------------------------------------------
-- Imports
-- -------------------------------------------------------------------

import Application.UseCases.TodoUseCases
  ( createNewTodo
  , getTodo
  , removeTodo
  , updateExistingTodo
  )

import Control.Monad.IO.Class (liftIO)

import Domain.Repositories.TodoRepository
  ( NewTodo
  , Todo
  , TodoRepository (getAllTodos)
  , ValidationError
  )

import Flow ((<|))

import Infrastructure.Repositories.SQLiteTodoRepository (SQLiteRepo (..))

import Servant
  ( Capture
  , Delete
  , Get
  , Handler
  , JSON
  , Post
  , Put
  , ReqBody
  , Server
  , type (:<|>) (..)
  , type (:>)
  )

-- -------------------------------------------------------------------
-- API Definitions
-- -------------------------------------------------------------------

-- | API type definition for Todo operations
--
-- Defines the following endpoints:
--
-- * GET    /api/todos - Get all todos
-- * POST   /api/todos - Create a new todo
-- * GET    /api/todos/:id - Get a specific todo
-- * PUT    /api/todos/:id - Update a todo
-- * DELETE /api/todos/:id - Delete a todo
type TodoAPI =
  "api" :> "todos" :> Get '[JSON] [Todo]
    :<|> "api"
      :> "todos"
      :> ReqBody '[JSON] NewTodo
      :> Post '[JSON] (Either ValidationError [Todo])
    :<|> "api" :> "todos" :> Capture "todoId" Int :> Get '[JSON] [Todo]
    :<|> "api"
      :> "todos"
      :> Capture "todoId" Int
      :> ReqBody '[JSON] Todo
      :> Put '[JSON] (Either ValidationError [Todo])
    :<|> "api" :> "todos" :> Capture "todoId" Int :> Delete '[JSON] [Todo]

-- | API server implementation for Todo operations
todoServer :: Server TodoAPI
todoServer =
  getAll
    :<|> postOne
    :<|> getOne
    :<|> putOne
    :<|> delOne
  where
    -- \| Get all todos
    getAll :: Handler [Todo]
    getAll = liftIO <| runSQLiteRepo getAllTodos

    -- \| Create a new todo
    postOne :: NewTodo -> Handler (Either ValidationError [Todo])
    postOne = liftIO . runSQLiteRepo . createNewTodo

    -- \| Get a specific todo by ID
    getOne :: Int -> Handler [Todo]
    getOne = liftIO . runSQLiteRepo . getTodo

    -- \| Update a todo
    putOne :: Int -> Todo -> Handler (Either ValidationError [Todo])
    putOne todoId = liftIO . runSQLiteRepo . updateExistingTodo todoId

    -- \| Delete a todo
    delOne :: Int -> Handler [Todo]
    delOne = liftIO . runSQLiteRepo . removeTodo
