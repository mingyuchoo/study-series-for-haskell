module GitPuller.Infrastructure.Filesystem (
  PathKind (..),
  pathKind,
  listDirectory,
  normalizeRoot,
)
where

import Control.Exception (IOException, try)
import Data.List (dropWhileEnd)
import Foreign.C.Error (Errno (..), eNOENT, eNOTDIR)
import GHC.IO.Exception (IOException (ioe_errno))
import GitPuller.Application.Ports (Entry (..))
import GitPuller.Application.Ports qualified as Ports
import GitPuller.Infrastructure.Failure qualified as Failure
import System.Directory qualified as Directory
import System.FilePath ((</>))
import System.Posix.Files (getSymbolicLinkStatus, isDirectory, isRegularFile, isSymbolicLink)

data PathKind = Directory | Regular | Symlink | Other | Missing | Unavailable
  deriving (Eq, Show)

pathKind :: FilePath -> IO PathKind
pathKind location = either unreadable readable <$> try (getSymbolicLinkStatus location)
 where
  readable status
    | isDirectory status = Directory
    | isRegularFile status = Regular
    | isSymbolicLink status = Symlink
    | otherwise = Other
  unreadable :: IOException -> PathKind
  unreadable failure
    | fmap Errno (ioe_errno failure) `elem` [Just eNOENT, Just eNOTDIR] = Missing
    | otherwise = Unavailable

entry :: FilePath -> FilePath -> IO Entry
entry parent name = Entry location . entryKind <$> pathKind location
 where
  location = parent </> name
  entryKind Directory = Ports.Directory
  entryKind Regular = Ports.Regular
  entryKind Missing = Ports.Unavailable
  entryKind Unavailable = Ports.Unavailable
  entryKind Symlink = Ports.Other
  entryKind Other = Ports.Other

listDirectory :: FilePath -> IO (Either String [Entry])
listDirectory location = do
  listed <- try (Directory.listDirectory location)
  case listed of
    Left failure -> pure (Left (Failure.reasonWithLocation failure))
    Right names -> Right <$> traverse (entry location) names

normalizeRoot :: FilePath -> IO (Either String FilePath)
normalizeRoot location = do
  kind <- pathKind trimmed
  case kind of
    Directory -> either unreadable Right <$> try readableRoot
    _ -> pure (Left "start path must be a readable directory")
 where
  trimmed = case dropWhileEnd (== '/') location of
    "" -> take 1 location
    withoutSlashes -> withoutSlashes
  readableRoot = do
    root <- Directory.canonicalizePath trimmed
    root <$ Directory.listDirectory root
  unreadable :: IOException -> Either String FilePath
  unreadable _ = Left "cannot read start directory"
