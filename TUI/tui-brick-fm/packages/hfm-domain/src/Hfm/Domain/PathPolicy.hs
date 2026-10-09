module Hfm.Domain.PathPolicy
  ( validDestination, validDirectoryName, requestedPath, destinationPath, isWithin ) where

import System.FilePath
  ( equalFilePath, isAbsolute, normalise, splitDirectories, takeFileName, (</>) )

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
  let parent = splitDirectories (normalise base)
      candidate = splitDirectories (normalise path)
  in length parent <= length candidate && and (zipWith equalFilePath parent candidate)
