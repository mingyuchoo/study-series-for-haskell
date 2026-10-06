module Hfm.Application.Ports (FileSystem (..), FileError (..), errorText) where

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
  , destinationFor :: FilePath -> FilePath -> FilePath -> m (Either FileError FilePath)
  }

errorText :: FileError -> T.Text
errorText Missing = "파일이 존재하지 않습니다"
errorText PermissionDenied = "파일 접근 권한이 없습니다"
errorText (FileFailure value) = value
