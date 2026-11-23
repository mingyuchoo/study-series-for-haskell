module Domain.Model
  ( User (..)
  ) where

data User = User
  { userId   :: Int
  , userName :: String
  }
  deriving (Eq, Show)
