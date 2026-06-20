module Infrastructure.Repositories.Operations.DatabaseOperations
  ( -- * Database Operations
    initializeDatabase
  ) where

-- -------------------------------------------------------------------
-- Imports
-- -------------------------------------------------------------------

import Infrastructure.Repositories.SQLiteTodoRepository (migrate)

-- -------------------------------------------------------------------
-- Database Operations
-- -------------------------------------------------------------------

-- | Initialize the database
--
-- Creates the necessary tables if they don't exist.
-- This function should be called when the application starts.
initializeDatabase :: IO ()
initializeDatabase = migrate
