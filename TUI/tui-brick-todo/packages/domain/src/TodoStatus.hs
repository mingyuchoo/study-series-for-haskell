{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}

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
  , nextStatus
  , parseStatus
  , renderStatus
  , registered
  , resetToRegistered
  , startProgress
  , statusToString
  , stringToStatus
  ) where

data TodoStatusType = Registered | InProgress | Cancelled | Completed
  deriving (Eq, Show)

data TodoStatus (a :: TodoStatusType) where
  StatusRegistered :: TodoStatus 'Registered
  StatusInProgress :: TodoStatus 'InProgress
  StatusCancelled :: TodoStatus 'Cancelled
  StatusCompleted :: TodoStatus 'Completed

instance Show (TodoStatus a) where
  show StatusRegistered = "Registered"
  show StatusInProgress = "InProgress"
  show StatusCancelled = "Cancelled"
  show StatusCompleted = "Completed"

registered :: TodoStatus 'Registered
registered = StatusRegistered

startProgress :: TodoStatus 'Registered -> TodoStatus 'InProgress
startProgress StatusRegistered = StatusInProgress

cancel :: TodoStatus 'InProgress -> TodoStatus 'Cancelled
cancel StatusInProgress = StatusCancelled

complete :: TodoStatus 'Cancelled -> TodoStatus 'Completed
complete StatusCancelled = StatusCompleted

resetToRegistered :: TodoStatus 'Completed -> TodoStatus 'Registered
resetToRegistered StatusCompleted = StatusRegistered

data AnyStatus where AnyStatus :: TodoStatus a -> AnyStatus

instance Show AnyStatus where
  show (AnyStatus s) = show s

statusToString :: TodoStatus a -> String
statusToString StatusRegistered = "registered"
statusToString StatusInProgress = "in_progress"
statusToString StatusCancelled = "cancelled"
statusToString StatusCompleted = "completed"

stringToStatus :: String -> Maybe AnyStatus
stringToStatus "registered" = Just (AnyStatus StatusRegistered)
stringToStatus "in_progress" = Just (AnyStatus StatusInProgress)
stringToStatus "cancelled" = Just (AnyStatus StatusCancelled)
stringToStatus "completed" = Just (AnyStatus StatusCompleted)
stringToStatus _ = Nothing

isCompleted :: AnyStatus -> Bool
isCompleted (AnyStatus StatusCompleted) = True
isCompleted _ = False

isCancelled :: AnyStatus -> Bool
isCancelled (AnyStatus StatusCancelled) = True
isCancelled _ = False

isInProgress :: AnyStatus -> Bool
isInProgress (AnyStatus StatusInProgress) = True
isInProgress _ = False

isRegistered :: AnyStatus -> Bool
isRegistered (AnyStatus StatusRegistered) = True
isRegistered _ = False

nextStatus :: TodoStatusType -> TodoStatusType
nextStatus Registered = InProgress
nextStatus InProgress = Cancelled
nextStatus Cancelled = Completed
nextStatus Completed = Registered

renderStatus :: TodoStatusType -> String
renderStatus Registered = "registered"
renderStatus InProgress = "in_progress"
renderStatus Cancelled = "cancelled"
renderStatus Completed = "completed"

parseStatus :: String -> Maybe TodoStatusType
parseStatus "registered" = Just Registered
parseStatus "in_progress" = Just InProgress
parseStatus "cancelled" = Just Cancelled
parseStatus "completed" = Just Completed
parseStatus _ = Nothing
