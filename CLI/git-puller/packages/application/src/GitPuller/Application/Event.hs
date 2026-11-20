module GitPuller.Application.Event
  ( Event (..)
  ) where

import GitPuller.Domain.Outcome (Outcome)

data Event = Scanning
           | Discovered
           | Processing Int
           | Inspecting FilePath
           | Pulling FilePath
           | Processed Outcome
  deriving (Eq, Show)
