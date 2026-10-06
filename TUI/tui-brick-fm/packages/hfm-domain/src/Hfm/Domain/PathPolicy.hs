module Hfm.Domain.PathPolicy
  ( validDestination, validDirectoryName, requestedPath, destinationPath, isWithin ) where

import System.FilePath
  ( addTrailingPathSeparator, isAbsolute, normalise, takeFileName, (</>) )
import Data.List (isPrefixOf)

validDestination :: FilePath -> Bool
validDestination input = not (null input) && input /= "." && input /= ".."

validDirectoryName :: FilePath -> Bool
validDirectoryName input = validDestination input && not (isAbsolute input) && takeFileName input == input

requestedPath :: FilePath -> FilePath -> FilePath
requestedPath cwd input = normalise (if isAbsolute input then input else cwd </> input)

-- The caller supplies the filesystem fact; the naming rule itself is pure.
destinationPath :: FilePath -> FilePath -> Bool -> FilePath
destinationPath source requested isDirectory =
  if isDirectory then requested </> takeFileName source else requested

-- Canonical paths must be supplied by the adapter for symlink-safe checks.
isWithin :: FilePath -> FilePath -> Bool
isWithin base path =
  let parent = normalise base
      candidate = normalise path
  in candidate == parent || addTrailingPathSeparator parent `isPrefixOf` candidate
