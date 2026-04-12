{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}

-- | Domain entities for the Todo application
module Domain.Repositories.Entities.Todo
    ( -- * Data Types
      NewTodo (..)
    , Priority (..)
    , Status (TodoStatus, DoingStatus, DoneStatus)
    , Todo (..)
    , ValidationError (..)
      -- * Functions
    , mkNewTodo
    , mkTodo
    , validateTodoTitle
    ) where

-- -------------------------------------------------------------------
-- Imports
-- -------------------------------------------------------------------

import           Data.Aeson                      (FromJSON (..), ToJSON (..),
                                                  Value (..))
import           Data.Text                       (Text)
import qualified Data.Text                       as T
import           Data.Time                       (UTCTime)

import           Database.SQLite.Simple          (FromRow (..), ToRow (..),
                                                  field)
import           Database.SQLite.Simple.Internal (RowParser)

import           Flow                            ((<|))

import           GHC.Generics                    (Generic)

-- -------------------------------------------------------------------
-- Entities
-- -------------------------------------------------------------------

-- | Priority levels for todos
data Priority = Low -- ^ Low priority tasks
              | Medium -- ^ Medium priority tasks
              | High -- ^ High priority tasks
     deriving (Bounded, Eq, Generic, Read)

-- | Custom Enum instance for Priority to handle wrapping around
instance Enum Priority where
    -- Convert to Int
    fromEnum Low    = 0
    fromEnum Medium = 1
    fromEnum High   = 2

    -- Convert from Int with wrapping
    toEnum n = case n `mod` 3 of
        0 -> Low
        1 -> Medium
        2 -> High
        _ -> error "Impossible case in Priority toEnum"

    -- Custom succ with wrapping
    succ High   = Low
    succ Medium = High
    succ Low    = Medium

    -- Custom pred with wrapping
    pred Low    = High
    pred High   = Medium
    pred Medium = Low

-- | Show instance for Priority
instance Show Priority where
    show Low    = "Low"
    show Medium = "Medium"
    show High   = "High"

-- | Custom JSON instances for Priority
instance FromJSON Priority where
    parseJSON (String t) = case T.unpack t of
        "Low"    -> pure Low
        "Medium" -> pure Medium
        "High"   -> pure High
        _        -> fail <| "Unknown priority: " ++ T.unpack t
    parseJSON _ = fail "Expected String for Priority"

instance ToJSON Priority where
    toJSON Low    = String "Low"
    toJSON Medium = String "Medium"
    toJSON High   = String "High"

-- | Status levels for todos
data Status = TodoStatus -- ^ Not started
            | DoingStatus -- ^ In progress
            | DoneStatus -- ^ Completed
     deriving (Bounded, Eq, Generic, Read)

-- | Custom Enum instance for Status to handle wrapping around
instance Enum Status where
    -- Convert to Int
    fromEnum TodoStatus  = 0
    fromEnum DoingStatus = 1
    fromEnum DoneStatus  = 2

    -- Convert from Int with wrapping
    toEnum n = case n `mod` 3 of
        0 -> TodoStatus
        1 -> DoingStatus
        2 -> DoneStatus
        _ -> error "Impossible case in Status toEnum"

    -- Custom succ with wrapping
    succ DoneStatus  = TodoStatus
    succ DoingStatus = DoneStatus
    succ TodoStatus  = DoingStatus

    -- Custom pred with wrapping
    pred TodoStatus  = DoneStatus
    pred DoneStatus  = DoingStatus
    pred DoingStatus = TodoStatus

-- | Show instance for Status
instance Show Status where
    show TodoStatus  = "Todo"
    show DoingStatus = "Doing"
    show DoneStatus  = "Done"

-- | Custom JSON instances for Status
instance FromJSON Status where
    parseJSON (String t) = case T.unpack t of
        "TodoStatus"  -> pure TodoStatus
        "DoingStatus" -> pure DoingStatus
        "DoneStatus"  -> pure DoneStatus
        _             -> fail <| "Unknown status: " ++ T.unpack t
    parseJSON _ = fail "Expected String for Status"

instance ToJSON Status where
    toJSON TodoStatus  = String "Todo"
    toJSON DoingStatus = String "Doing"
    toJSON DoneStatus  = String "Done"

-- | Core entity representing a Todo item
data Todo = Todo { todoId    :: !Int
                   -- ^ Unique identifier
                 , todoTitle :: !Text
                   -- ^ Title of the todo
                 , createdAt :: !UTCTime
                   -- ^ Creation timestamp
                 , priority  :: !Priority
                   -- ^ Priority level
                 , status    :: !Status
                   -- ^ Current status
                 }
     deriving (Eq, Generic, Show)

-- | Helper function to create a new Todo
mkTodo :: Int -> Text -> UTCTime -> Priority -> Status -> Todo
mkTodo todoId' title time prio stat = Todo
    { todoId = todoId'
    , todoTitle = title
    , createdAt = time
    , priority = prio
    , status = stat
    }

-- | Used for creating a new todo without specifying todoId
data NewTodo = NewTodo
    { newTodoTitle    :: Text
    , newTodoPriority :: Priority
    } deriving (Eq, Generic, Show)

-- | Helper function to create a new NewTodo
mkNewTodo :: Text -> NewTodo
mkNewTodo title = NewTodo title Medium

-- | Validation error response
newtype ValidationError = ValidationError { errorMessage :: Text }
     deriving (Eq, Generic, Show)

-- | JSON instances
instance FromJSON Todo
instance ToJSON Todo

instance FromJSON NewTodo
instance ToJSON NewTodo

instance ToJSON ValidationError
instance FromJSON ValidationError

-- | Database mapping instances
instance FromRow Todo where
  fromRow = do
    tId <- field
    tTitle <- field
    tCreatedAt <- field
    tPriorityStr <- field :: RowParser String
    tStatusStr <- field :: RowParser String
    let tPriority = case tPriorityStr of
          "Low"    -> Low
          "Medium" -> Medium
          "High"   -> High
          _        -> Medium  -- Default to Medium if unknown
    let tStatus = case tStatusStr of
          "Done"  -> DoneStatus
          "Doing" -> DoingStatus
          _       -> TodoStatus  -- Default to Todo if unknown
    pure <| Todo tId tTitle tCreatedAt tPriority tStatus

instance ToRow Todo where
  toRow Todo{..} = toRow (todoId, todoTitle, createdAt, show priority, show status)

-- | Validate a todo title against business rules
--
-- Rules:
-- * Cannot be empty
-- * Must be at least 3 characters
-- * Must be at most 50 characters
validateTodoTitle :: Text -> Either ValidationError ()
validateTodoTitle title
  | T.null title = Left <| ValidationError "TodoTitle cannot be empty"
  | T.length title < 3 = Left <| ValidationError "TodoTitle must be at least 3 characters long"
  | T.length title > 50 = Left <| ValidationError "TodoTitle must be at most 50 characters long"
  | otherwise = Right ()
