{-# LANGUAGE CPP #-}
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
import System.FilePath (equalFilePath, isAbsolute, normalise, takeDirectory, (</>))
import System.IO.Error (isDoesNotExistError)
#if defined(mingw32_HOST_OS)
import Data.Bits ((.&.))
import System.Directory
  ( createDirectoryLink, createFileLink
  , getSymbolicLinkTarget, removeDirectoryLink )
import System.Win32.File
  ( getFileAttributes, getFileAttributesExStandard, WIN32_FILE_ATTRIBUTE_DATA (..)
  , fILE_ATTRIBUTE_DIRECTORY, fILE_ATTRIBUTE_REPARSE_POINT )
#else
import System.Posix.Files
  ( createSymbolicLink, fileSize, getSymbolicLinkStatus, isDirectory
  , isSymbolicLink, isRegularFile, readSymbolicLink
  )
#endif

entryInfo :: FilePath -> IO (EntryKind, Integer)
#if defined(mingw32_HOST_OS)
entryInfo path = do
  status <- getFileAttributesExStandard path
  let attributes = fadFileAttributes status
      kind | attributes .&. fILE_ATTRIBUTE_REPARSE_POINT /= 0 = SymbolicLink
           | attributes .&. fILE_ATTRIBUTE_DIRECTORY /= 0 = Directory
           | otherwise = RegularFile
  pure (kind, fromIntegral (fadFileSize status))
#else
entryInfo path = do
  status <- getSymbolicLinkStatus path
  let kind | isSymbolicLink status = SymbolicLink
           | isDirectory status = Directory
           | isRegularFile status = RegularFile
           | otherwise = Special
  pure (kind, fromIntegral (fileSize status))
#endif

pathExists :: FilePath -> IO Bool
pathExists path = (entryInfo path >> pure True) `catch` missing
  where
    missing :: IOException -> IO Bool
    missing e | isDoesNotExistError e = pure False
              | otherwise = throwIO e

readEntries :: Bool -> FilePath -> IO [Entry]
readEntries showHidden dir = do
  names <- listDirectory dir
  entries <- forM (visibleNames showHidden names) $ \name -> do
    (kind, size) <- entryInfo (dir </> name)
    pure (Entry name kind size)
  let root = isAbsolute dir && equalFilePath (normalise dir) (takeDirectory (normalise dir))
      parent = if root then [] else [Entry ".." Parent 0]
  pure (parent ++ sortEntries entries)
-- A destination may be a directory or a new path for a rename.
destinationFor :: FilePath -> FilePath -> FilePath -> IO FilePath
destinationFor cwd source input = do
  let requested = requestedPath cwd input
  isDir <- doesDirectoryExist requested
  pure (destinationPath source requested isDir)

ensureVacant :: FilePath -> FilePath -> IO ()
ensureVacant source target = do
  when (equalFilePath source target) $
    ioError (userError "원본과 대상 경로가 같습니다")
  occupied <- pathExists target
  when occupied $ ioError (userError "대상 경로가 이미 존재합니다")
  targetParent <- doesDirectoryExist (takeDirectory target)
  unless targetParent $ ioError (userError "대상 상위 디렉터리가 없습니다")
  sourceDir <- doesDirectoryExist source
  when sourceDir $ do
    (kind, _) <- entryInfo source
    unless (kind == SymbolicLink) $ do
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
  (kind, _) <- entryInfo source
  if kind == SymbolicLink
    then copyLink source target
    else if kind == Directory
      then do
        createDirectory target
        names <- listDirectory source
        mapM_ (\name -> copyTree (source </> name) (target </> name)) names
      else if kind == RegularFile
        then copyFile source target
        else ioError (userError "특수 파일은 복사할 수 없습니다")

copyLink :: FilePath -> FilePath -> IO ()
#if defined(mingw32_HOST_OS)
copyLink source target = do
  linkTarget <- getSymbolicLinkTarget source
  directory <- isDirectoryLink source
  if directory then createDirectoryLink linkTarget target else createFileLink linkTarget target

-- Read the link's own attributes so dangling directory links retain their type.
isDirectoryLink :: FilePath -> IO Bool
isDirectoryLink path = (/= 0) . (.&. fILE_ATTRIBUTE_DIRECTORY) <$> getFileAttributes path
#else
copyLink source target = readSymbolicLink source >>= (`createSymbolicLink` target)
#endif

cleanup :: FilePath -> IO ()
cleanup path = do
  exists <- pathExists path
  when exists (deleteEntry path)

moveEntry :: FilePath -> FilePath -> IO ()
moveEntry source target = ensureVacant source target >> renamePath source target

deleteEntry :: FilePath -> IO ()
deleteEntry path = do
  (kind, _) <- entryInfo path
  if kind == Directory
    then do
      names <- listDirectory path
      mapM_ (deleteEntry . (path </>)) names
      removeDirectory path
    else do
#if defined(mingw32_HOST_OS)
      directoryLink <- isDirectoryLink path
      if directoryLink then removeDirectoryLink path else removeFile path
#else
      removeFile path
#endif

makeDirectory :: FilePath -> IO ()
makeDirectory path = do
  occupied <- pathExists path
  when occupied $ ioError (userError "대상 경로가 이미 존재합니다")
  createDirectory path
