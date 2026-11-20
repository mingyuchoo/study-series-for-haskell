module GitPuller.Application.Ports (
  EntryKind (..),
  Entry (..),
  Event (..),
  Ports (..),
)
where

import GitPuller.Domain.Outcome (Outcome)
import GitPuller.Domain.Repository (Inspection)

data EntryKind = Directory | Regular | Other | Unavailable
  deriving (Eq, Show)

data Entry = Entry
  { path :: FilePath
  , kind :: EntryKind
  }
  deriving (Eq, Show)

data Event
  = Scanning
  | Discovered
  | Processing Int
  | Inspecting FilePath
  | Pulling FilePath
  | Processed Outcome
  deriving (Eq, Show)

data Ports effect = Ports
  { listDirectory :: FilePath -> effect (Either String [Entry])
  , inspectRepository :: FilePath -> effect (Either String Inspection)
  , locateCommonDirectory :: FilePath -> effect (Either String FilePath)
  , pull :: FilePath -> effect (Either String ())
  , report :: Event -> effect ()
  }
