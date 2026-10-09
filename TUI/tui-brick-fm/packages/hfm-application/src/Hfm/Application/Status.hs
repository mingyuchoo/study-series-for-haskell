module Hfm.Application.Status (Status (..)) where

import Hfm.Application.Ports (FileError)

-- Semantic outcomes. A presentation adapter owns wording and localization.
data Status
  = Ready
  | UnknownCommand
  | Cancelled
  | SpecialFileUnsupported
  | BinaryPreviewUnsupported
  | InvalidDestination
  | DirectoryCreated
  | Copied
  | Moved
  | Deleted
  | DeletionCancelled
  | EditorFinished Int
  | CommandFinished Int
  | InvalidCommand
  | CurrentDirectory FilePath
  | Failed FileError
  deriving (Eq, Show)
