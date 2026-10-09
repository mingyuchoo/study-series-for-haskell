module Hfm.Infrastructure.Ports (ioFileSystem, ioProcesses, capture, formatFileError) where

import Control.Exception (IOException, try)
import qualified Data.ByteString as BS
import qualified Data.Text
import Hfm.Application.Effects.Ports
import Hfm.Application.Error
import qualified Hfm.Infrastructure.FileSystem as FS
import qualified Hfm.Infrastructure.Process as Process
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
  }

ioProcesses :: Processes IO
ioProcesses = Processes
  { editFile = \editor cwd path -> capture (Process.editFile editor cwd path)
  , runCommand = \cwd command -> capture (Process.runCommand cwd command)
  }
