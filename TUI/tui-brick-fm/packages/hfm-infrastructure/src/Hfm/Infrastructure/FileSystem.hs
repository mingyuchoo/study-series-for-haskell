{-# LANGUAGE OverloadedStrings #-}

module Hfm.Infrastructure.FileSystem
  ( Entry (..)
  , EntryKind (..)
  , readEntries
  , copyEntry
  , moveEntry
  , deleteEntry
  , makeDirectory
  , destinationFor
  , pathExists
  ) where

import Control.Exception (IOException, catch, onException, throwIO)
import Control.Monad (forM, unless, when)
import Hfm.Domain.PathPolicy (requestedPath, destinationPath, isWithin)
import Hfm.Domain.Entry
import System.Directory
  ( canonicalizePath, copyFile, createDirectory, doesDirectoryExist
  , listDirectory, removeDirectory, removeFile, renamePath
  )
import System.FilePath (normalise, takeDirectory, (</>))
import System.IO.Error (isDoesNotExistError)
import System.Posix.Files
  ( createSymbolicLink, fileSize, getSymbolicLinkStatus, isDirectory
  , isSymbolicLink, isRegularFile, readSymbolicLink
  )

pathExists :: FilePath -> IO Bool
pathExists path = (getSymbolicLinkStatus path >> pure True) `catch` missing
  where
    missing :: IOException -> IO Bool
    missing e | isDoesNotExistError e = pure False
              | otherwise = throwIO e

readEntries :: Bool -> FilePath -> IO [Entry]
readEntries showHidden dir = do
  names <- listDirectory dir
  entries <- forM (visibleNames showHidden names) $ \name -> do
    status <- getSymbolicLinkStatus (dir </> name)
    let kind | isSymbolicLink status = SymbolicLink
             | isDirectory status = Directory
             | isRegularFile status = RegularFile
             | otherwise = Special
    pure (Entry name kind (fromIntegral (fileSize status)))
  let parent = if normalise dir == "/" then [] else [Entry ".." Parent 0]
  pure (parent ++ sortEntries entries)
-- A destination may be a directory or a new path for a rename.
destinationFor :: FilePath -> FilePath -> FilePath -> IO FilePath
destinationFor cwd source input = do
  let requested = requestedPath cwd input
  isDir <- doesDirectoryExist requested
  pure (destinationPath source requested isDir)

ensureVacant :: FilePath -> FilePath -> IO ()
ensureVacant source target = do
  when (normalise source == normalise target) $
    ioError (userError "원본과 대상 경로가 같습니다")
  occupied <- pathExists target
  when occupied $ ioError (userError "대상 경로가 이미 존재합니다")
  targetParent <- doesDirectoryExist (takeDirectory target)
  unless targetParent $ ioError (userError "대상 상위 디렉터리가 없습니다")
  sourceDir <- doesDirectoryExist source
  when sourceDir $ do
    status <- getSymbolicLinkStatus source
    unless (isSymbolicLink status) $ do
      base <- canonicalizePath source
      parent <- canonicalizePath (takeDirectory target)
      when (isWithin base parent) $
        ioError (userError "디렉터리를 자기 내부로 복사하거나 이동할 수 없습니다")

copyEntry :: FilePath -> FilePath -> IO ()
copyEntry source target = do
  ensureVacant source target
  copyTree source target `onException` cleanup target

copyTree :: FilePath -> FilePath -> IO ()
copyTree source target = do
  status <- getSymbolicLinkStatus source
  if isSymbolicLink status
    then readSymbolicLink source >>= (`createSymbolicLink` target)
    else if isDirectory status
      then do
        createDirectory target
        names <- listDirectory source
        mapM_ (\name -> copyTree (source </> name) (target </> name)) names
      else if isRegularFile status
        then copyFile source target
        else ioError (userError "특수 파일은 복사할 수 없습니다")

cleanup :: FilePath -> IO ()
cleanup path = do
  exists <- pathExists path
  when exists (deleteEntry path)

moveEntry :: FilePath -> FilePath -> IO ()
moveEntry source target = ensureVacant source target >> renamePath source target

deleteEntry :: FilePath -> IO ()
deleteEntry path = do
  status <- getSymbolicLinkStatus path
  if isDirectory status && not (isSymbolicLink status)
    then do
      names <- listDirectory path
      mapM_ (deleteEntry . (path </>)) names
      removeDirectory path
    else removeFile path

makeDirectory :: FilePath -> IO ()
makeDirectory path = do
  occupied <- pathExists path
  when occupied $ ioError (userError "대상 경로가 이미 존재합니다")
  createDirectory path
