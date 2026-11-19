module Hfm.DevTools.Workspace (readWorkspace) where

import           Control.Monad             (forM)

import           Data.List                 (isSuffixOf, sort)
import qualified Data.Text                 as Text
import qualified Data.Text.IO              as Text

import           Hfm.DevTools.Architecture (Workspace, workspaceFolders)

import           System.Directory          (doesDirectoryExist, doesFileExist,
                                            listDirectory)
import           System.FilePath           ((</>))
import           System.IO                 (IOMode (ReadMode), hSetEncoding,
                                            utf8, withFile)

readWorkspace :: FilePath -> IO Workspace
readWorkspace root = do
  manifests <- mapM readOptional (["stack.yaml", "cabal.project"] ++ map (++ "/package.yaml") workspaceFolders)
  sources <- forM workspaceFolders $ \folder -> collect (folder ++ if folder == "apps/hfm" then "/app" else "/src")
  pure (concat manifests ++ concat sources)
  where
    readOptional path = do
      exists <- doesFileExist (root </> path)
      if exists then readSource path else pure []
    readSource path = do
      contents <- withFile (root </> path) ReadMode $ \handle -> do
        hSetEncoding handle utf8
        Text.hGetContents handle
      pure [(path, Text.unpack contents)]
    collect path = do
      directory <- doesDirectoryExist (root </> path)
      if not directory then pure [] else do
        names <- sort <$> listDirectory (root </> path)
        files <- forM names $ \name -> do
          let relative = path ++ "/" ++ name
          nested <- doesDirectoryExist (root </> relative)
          if nested then collect relative else
            if ".hs" `isSuffixOf` relative then readSource relative else pure []
        pure (concat files)
