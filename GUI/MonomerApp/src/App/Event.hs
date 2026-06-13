module App.Event
  ( AppEvent (..)
  )
where

data AppEvent
  = AppInit
  | AppIncrease
  deriving (Eq, Show)
