module Infrastructure.Repositories.DatabaseRepository
  ( initializeDatabase
  , migrateDatabase
  ) where

-- -------------------------------------------------------------------
-- Imports
-- -------------------------------------------------------------------

import Infrastructure.Repositories.Operations.DatabaseOperations (initializeDatabase)

-- -------------------------------------------------------------------
-- Repository
-- -------------------------------------------------------------------

-- Repository interface for database operations
class DatabaseRepository m where
  migrateDatabase :: m ()
