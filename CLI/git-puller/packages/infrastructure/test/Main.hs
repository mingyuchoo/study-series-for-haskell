module Main (main) where

import Control.Concurrent.STM (
  atomically,
  check,
  modifyTVar',
  newTVarIO,
  readTVar,
  readTVarIO,
  writeTVar,
 )
import Control.Monad (when)
import Data.IORef (IORef, modifyIORef', newIORef, readIORef)
import Data.List (delete)
import GitPuller.Application.Ports (Entry (..), EntryKind (..), Event (..), Ports (..))
import GitPuller.Domain.Outcome (Outcome (..), Status (..))
import GitPuller.Domain.Repository (Branch (..), Inspection (..), Operation (..), State (..))
import GitPuller.Domain.Update (Mode (..))
import GitPuller.Infrastructure.BatchRunner qualified as BatchRunner
import GitPuller.Infrastructure.Git qualified as Git
import GitPuller.Infrastructure.Process qualified as Process
import GitPuller.Infrastructure.WorkerPool qualified as WorkerPool
import System.Environment (getEnvironment)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import Test.Hspec (Spec, describe, hspec, it, shouldBe, shouldReturn, shouldThrow)

main :: IO ()
main = hspec $ do
  batchRunnerSpec
  workerPoolSpec
  processSpec
  gitEnvironmentSpec

clean :: Inspection
clean = Standalone State{branch = Attached, operation = Idle, upstream = True, dirty = False}

record :: IORef [item] -> item -> IO ()
record history item = modifyIORef' history (item :)

recorded :: IORef [item] -> IO [item]
recorded history = reverse <$> readIORef history

batchRunnerSpec :: Spec
batchRunnerSpec = describe "BatchRunner.run" $ do
  it "discovers, inspects and reports without pulling during a dry run" $ do
    inspected <- newIORef []
    pulled <- newIORef []
    events <- newIORef []
    let listing "/" =
          Right
            [ Entry "/z" Directory
            , Entry "/link" Other
            , Entry "/a" Directory
            , Entry "/bad" Directory
            , Entry "/.git" Directory
            ]
        listing "/bad" = Left "blocked"
        listing _ = Right [Entry "/.git" Other, Entry "/unused" Other]
        ports =
          Ports
            { listDirectory = pure . listing
            , inspectRepository = \location -> Right clean <$ record inspected location
            , locateCommonDirectory = pure . Right
            , pull = \location -> Right () <$ record pulled location
            , report = record events
            }
        planned = Outcome "/" Planned
        blocked = Outcome "/bad" (Failed "blocked")
    BatchRunner.run ports 1 DryRun "/" `shouldReturn` [planned, blocked]
    recorded inspected `shouldReturn` ["/"]
    recorded pulled `shouldReturn` []
    recorded events
      `shouldReturn` [ Scanning
                     , Discovered
                     , Processing 2
                     , Inspecting "/"
                     , Processed planned
                     , Processed blocked
                     ]
  it "pulls eligible worktrees in path order and keeps going after a failure" $ do
    pulled <- newIORef []
    let listing "/" = [Entry "/z" Directory, Entry "/a" Directory]
        listing "/a" = [Entry "/a/.git" Regular]
        listing _ = [Entry "/z/.git" Directory]
        ports =
          Ports
            { listDirectory = pure . Right . listing
            , inspectRepository = const (pure (Right clean))
            , locateCommonDirectory = pure . Right
            , pull = \location ->
                (if location == "/a" then Left "failed" else Right ()) <$ record pulled location
            , report = const (pure ())
            }
    BatchRunner.run ports 1 Apply "/"
      `shouldReturn` [Outcome "/a" (Failed "failed"), Outcome "/z" Updated]
    recorded pulled `shouldReturn` ["/a", "/z"]
  it "pulls independent repositories concurrently but shared worktrees serially" $ do
    arrived <- newTVarIO (0 :: Int)
    active <- newTVarIO []
    overlapped <- newTVarIO False
    let commonDirectory location
          | location `elem` ["/a", "/b"] = "/shared"
          | otherwise = location
        enter directory = do
          atomically $ do
            busy <- readTVar active
            when (directory `elem` busy) (writeTVar overlapped True)
            writeTVar active (directory : busy)
            modifyTVar' arrived (+ 1)
          atomically (readTVar arrived >>= check . (>= 3))
        leave directory = atomically (modifyTVar' active (delete directory))
        listing "/" = map (`Entry` Directory) ["/a", "/b", "/c", "/d"]
        listing location = [Entry (location </> ".git") Directory]
        ports =
          Ports
            { listDirectory = pure . Right . listing
            , inspectRepository = const (pure (Right clean))
            , locateCommonDirectory = pure . Right . commonDirectory
            , pull = \location -> do
                enter (commonDirectory location)
                leave (commonDirectory location)
                pure (if location == "/c" then Left "failed" else Right ())
            , report = const (pure ())
            }
    BatchRunner.run ports 4 Apply "/"
      `shouldReturn` [ Outcome "/a" Updated
                     , Outcome "/b" Updated
                     , Outcome "/c" (Failed "failed")
                     , Outcome "/d" Updated
                     ]
    readTVarIO overlapped `shouldReturn` False

workerPoolSpec :: Spec
workerPoolSpec = describe "WorkerPool.mapConcurrently" $ do
  it "keeps results in item order" $
    WorkerPool.mapConcurrently 3 (pure . (* 2)) [1, 2, 3, 4 :: Int] `shouldReturn` [2, 4, 6, 8]
  it "rethrows a worker failure" $
    WorkerPool.mapConcurrently 3 failOnTwo [1, 2, 3 :: Int] `shouldThrow` (== userError "broken")
 where
  failOnTwo item
    | item == 2 = ioError (userError "broken")
    | otherwise = pure item

processSpec :: Spec
processSpec = describe "Process.run" $ do
  let shell script = getEnvironment >>= Process.run "/bin/sh" ["-c", script]
  it "captures large output on both streams with an empty standard input" $ do
    completed <-
      shell "if read -r line; then exit 9; fi; head -c 200000 /dev/zero; head -c 300000 /dev/zero >&2"
    completed
      `shouldBe` Right
        (Process.CompletedProcess ExitSuccess (replicate 200000 '\0') (replicate 300000 '\0'))
  it "reports termination by a signal" $ do
    completed <- shell "kill -TERM $$"
    fmap Process.status completed `shouldBe` Right (ExitFailure (-15))
  it "reports a program that cannot be started" $ do
    completed <- Process.run "/nonexistent/program" [] []
    completed `shouldBe` Left "No such file or directory"

gitEnvironmentSpec :: Spec
gitEnvironmentSpec =
  describe "Git.childEnvironment"
    $ it "drops repository overrides and disables prompts and optional locks"
    $ Git.childEnvironment
      [ ("GIT_DIR", "/tmp/other")
      , ("GIT_WORK_TREE", "/tmp/other")
      , ("GIT_INDEX_FILE", "/tmp/index")
      , ("GIT_CONFIG_GLOBAL", "/dev/null")
      , ("GIT_TRACE", "1")
      , ("GIT_TERMINAL_PROMPT", "1")
      , ("GIT_OPTIONAL_LOCKS", "1")
      ]
      `shouldBe` [ ("GIT_CONFIG_GLOBAL", "/dev/null")
                 , ("GIT_TRACE", "1")
                 , ("GIT_TERMINAL_PROMPT", "0")
                 , ("GIT_OPTIONAL_LOCKS", "0")
                 ]
