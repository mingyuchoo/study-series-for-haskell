module FileSearch (listFilesRecursive, listFilesWithIssues, shouldExclude) where

import Control.Exception (IOException, try)
import Fzh.Domain.Discovery (DiscoveryIssue (..))
import Fzh.Domain.Discovery qualified as Discovery
import System.Directory (doesDirectoryExist, listDirectory, pathIsSymbolicLink)
import System.FilePath (takeFileName, (</>))
import System.IO (hPutStrLn, stderr)

shouldExclude :: FilePath -> Bool
shouldExclude = Discovery.shouldExclude . takeFileName

listFilesWithIssues :: FilePath -> IO ([FilePath], [DiscoveryIssue])
listFilesWithIssues root = uncurry run (Discovery.startDiscovery root)
  where
    run state [] = case Discovery.discoveryResult state of
      Just result -> pure result
      Nothing -> ioError (userError "Discovery stopped before completion")
    run state (command : pending) = do
      event <- execute command
      let (next, commands) = Discovery.transitionDiscovery event state
      run next (commands ++ pending)
    execute (Discovery.ReadDirectory path) = do
      result <- attempt (listDirectory path)
      pure (Discovery.DirectoryRead path (map (\name -> (path </> name, name)) <$> result))
    execute (Discovery.InspectPath path) = do
      result <- attempt $ do
        symbolic <- pathIsSymbolicLink path
        directory <- doesDirectoryExist path
        pure $
          if directory
            then if symbolic then Discovery.SymbolicLink else Discovery.Directory
            else Discovery.RegularFile
      pure (Discovery.PathInspected path result)

attempt :: IO a -> IO (Either String a)
attempt operation = either (Left . show @IOException) Right <$> try operation

listFilesRecursive :: FilePath -> IO [FilePath]
listFilesRecursive root = do
  (files, issues) <- listFilesWithIssues root
  mapM_
    (\(DiscoveryIssue path problem) -> hPutStrLn stderr (path ++ ": " ++ problem))
    issues
  pure files
