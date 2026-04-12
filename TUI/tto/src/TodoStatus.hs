{-# LANGUAGE DataKinds      #-}
{-# LANGUAGE GADTs          #-}
{-# LANGUAGE KindSignatures #-}

-- | Todo status state machine using GADTs (Pure)
--
-- This module defines a type-safe state machine for todo statuses.
-- States: Registered -> InProgress -> Cancelled -> Completed -> Registered (cycle)
--
-- Pure components:
--   - TodoStatus: GADT representing valid states
--   - State transitions: Type-safe functions
--   - Serialization: To/from String for DB storage
--
-- Effects: NONE - All functions are pure
module TodoStatus
    ( AnyStatus (..)
    , TodoStatus (..)
    , TodoStatusType (..)
    , cancel
    , complete
    , isCancelled
    , isCompleted
    , isInProgress
    , isRegistered
    , registered
    , resetToRegistered
    , startProgress
    , statusToString
    , stringToStatus
    ) where

-- | Type-level status tags
data TodoStatusType = Registered | InProgress | Cancelled | Completed
     deriving (Eq, Show)

-- | GADT for type-safe todo status
data TodoStatus (a :: TodoStatusType) where StatusRegistered :: TodoStatus 'Registered
                                            StatusInProgress :: TodoStatus 'InProgress
                                            StatusCancelled :: TodoStatus 'Cancelled
                                            StatusCompleted :: TodoStatus 'Completed

-- | Show instance for TodoStatus
instance Show (TodoStatus a) where
    show StatusRegistered = "Registered"
    show StatusInProgress = "InProgress"
    show StatusCancelled  = "Cancelled"
    show StatusCompleted  = "Completed"

-- | Create a new todo in Registered state
registered :: TodoStatus 'Registered
registered = StatusRegistered

-- | Transition from Registered to InProgress
startProgress :: TodoStatus 'Registered -> TodoStatus 'InProgress
startProgress StatusRegistered = StatusInProgress

-- | Transition from InProgress to Cancelled
cancel :: TodoStatus 'InProgress -> TodoStatus 'Cancelled
cancel StatusInProgress = StatusCancelled

-- | Transition from Cancelled to Completed
complete :: TodoStatus 'Cancelled -> TodoStatus 'Completed
complete StatusCancelled = StatusCompleted

-- | Transition from Completed to Registered (cycle reset)
resetToRegistered :: TodoStatus 'Completed -> TodoStatus 'Registered
resetToRegistered StatusCompleted = StatusRegistered

-- | Existential wrapper for any status (for storage)
data AnyStatus where AnyStatus :: TodoStatus a -> AnyStatus

instance Show AnyStatus where
    show (AnyStatus s) = show s

-- | Convert status to string for database storage
statusToString :: TodoStatus a -> String
statusToString StatusRegistered = "registered"
statusToString StatusInProgress = "in_progress"
statusToString StatusCancelled  = "cancelled"
statusToString StatusCompleted  = "completed"

-- | Parse status from string (from database)
stringToStatus :: String -> Maybe AnyStatus
stringToStatus "registered"  = Just (AnyStatus StatusRegistered)
stringToStatus "in_progress" = Just (AnyStatus StatusInProgress)
stringToStatus "cancelled"   = Just (AnyStatus StatusCancelled)
stringToStatus "completed"   = Just (AnyStatus StatusCompleted)
stringToStatus _             = Nothing

-- | Check if status is completed
isCompleted :: AnyStatus -> Bool
isCompleted (AnyStatus StatusCompleted) = True
isCompleted _                           = False

-- | Check if status is cancelled
isCancelled :: AnyStatus -> Bool
isCancelled (AnyStatus StatusCancelled) = True
isCancelled _                           = False

-- | Check if status is in progress
isInProgress :: AnyStatus -> Bool
isInProgress (AnyStatus StatusInProgress) = True
isInProgress _                            = False

-- | Check if status is registered
isRegistered :: AnyStatus -> Bool
isRegistered (AnyStatus StatusRegistered) = True
isRegistered _                            = False
