module Hfm.Infrastructure.Ports (ioFileSystem, capture, formatFileError) where

import Control.Exception (IOException, try)
import qualified Data.ByteString as BS
import qualified Data.Text
import Hfm.Application.Ports
import qualified Hfm.Infrastructure.FileSystem as FS
import qualified System.Directory as Directory
import System.IO (IOMode (ReadMode), withBinaryFile)
import System.IO.Error (isDoesNotExistError, isPermissionError)

formatFileError :: IOException -> FileError
formatFileError e
  | isDoesNotExistError e = Missing
  | isPermissionError e = PermissionDenied
  | otherwise = FileFailure (Data.Text.pack (show e))

capture :: IO a -> IO (Either FileError a)
capture action = either (Left . formatFileError) Right <$> try action

ioFileSystem :: FileSystem IO
ioFileSystem = FileSystem
  { readEntries = \hidden path -> capture (FS.readEntries hidden path)
  , canonicalizePath = capture . Directory.canonicalizePath
  , doesDirectoryExist = capture . Directory.doesDirectoryExist
  , readPreview = \path -> capture (withBinaryFile path ReadMode (\h -> BS.hGet h 65536))
  , copyEntry = \source target -> capture (FS.copyEntry source target)
  , moveEntry = \source target -> capture (FS.moveEntry source target)
  , deleteEntry = capture . FS.deleteEntry
  , makeDirectory = capture . FS.makeDirectory
  , destinationFor = \cwd source input -> capture (FS.destinationFor cwd source input)
  }
