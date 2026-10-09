module Hfm.Application.Ports (FileSystem (..), FileError (..)) where

import qualified Data.ByteString as BS
import qualified Data.Text as T
import Hfm.Domain.Entry

-- The application owns the interface. Adapters provide implementations in any monad.
data FileError = Missing | PermissionDenied | FileFailure T.Text deriving (Eq, Show)

data FileSystem m = FileSystem
  { readEntries :: Bool -> FilePath -> m (Either FileError [Entry])
  , canonicalizePath :: FilePath -> m (Either FileError FilePath)
  , doesDirectoryExist :: FilePath -> m (Either FileError Bool)
  , readPreview :: FilePath -> m (Either FileError BS.ByteString)
  , copyEntry :: FilePath -> FilePath -> m (Either FileError ())
  , moveEntry :: FilePath -> FilePath -> m (Either FileError ())
  , deleteEntry :: FilePath -> m (Either FileError ())
  , makeDirectory :: FilePath -> m (Either FileError ())
  , editFile :: FilePath -> FilePath -> m (Either FileError Int)
  , runCommand :: FilePath -> T.Text -> m (Either FileError Int)
  }
