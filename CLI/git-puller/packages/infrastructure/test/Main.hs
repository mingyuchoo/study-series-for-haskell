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
import GitPuller.Application.Event (Event (..))
import GitPuller.Application.Roles (
  Cast (..),
  Inspector (..),
  Observer (..),
  Surveyor (..),
  Updater (..),
 )
import GitPuller.Domain.Discovery (Entry (..), EntryKind (..))
import GitPuller.Domain.Outcome (Outcome (..), Status (..))
import GitPuller.Domain.Repository (Branch (..), Inspection (..), Operation (..), State (State))
import GitPuller.Domain.Update (Mode (..))
import GitPuller.Infrastructure.BatchRunner qualified as BatchRunner
import GitPuller.Infrastructure.Descriptors qualified as Descriptors
import GitPuller.Infrastructure.Git qualified as Git
import GitPuller.Infrastructure.GitOutput (Layout (..), Snapshot (..))
import GitPuller.Infrastructure.GitOutput qualified as GitOutput
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
  gitOutputSpec
  descriptorsSpec

clean :: Inspection
clean =
  Standalone "/shared" (State Attached Idle True False)

record :: IORef [item] -> item -> IO ()
record history item = modifyIORef' history (item :)

recorded :: IORef [item] -> IO [item]
recorded history = reverse <$> readIORef history

cast ::
  (FilePath -> IO (Either String [Entry])) ->
  (FilePath -> IO (Either String Inspection)) ->
  (FilePath -> IO (Either String ())) ->
  (Event -> IO ()) ->
  Cast IO
cast list inspect update observe =
  Cast
    { surveyor = Surveyor{listDirectory = list}
    , inspector = Inspector{inspectRepository = inspect}
    , updater = Updater{pull = update}
    , observer = Observer{notify = observe}
    }

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
          cast
            (pure . listing)
            (\location -> Right clean <$ record inspected location)
            (\location -> Right () <$ record pulled location)
            (record events)
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
          cast
            (pure . Right . listing)
            (const (pure (Right clean)))
            (\location -> (if location == "/a" then Left "failed" else Right ()) <$ record pulled location)
            (const (pure ()))
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
        idle = State Attached Idle True False
        inspection location = Standalone (commonDirectory location) idle
        listing "/" = map (`Entry` Directory) ["/a", "/b", "/c", "/d"]
        listing location = [Entry (location </> ".git") Directory]
        ports =
          cast
            (pure . Right . listing)
            (pure . Right . inspection)
            ( \location -> do
                enter (commonDirectory location)
                leave (commonDirectory location)
                pure (if location == "/c" then Left "failed" else Right ())
            )
            (const (pure ()))
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

gitOutputSpec :: Spec
gitOutputSpec = describe "GitOutput" $ do
  let separated = concatMap (<> "--git-puller-field\n")
  it "reads the layout of a standalone worktree with an empty superproject" $
    GitOutput.parseLayout (separated ["/a\n", "/a/.git\n", "/a/.git\n"])
      `shouldBe` Just (Layout "/a" "/a/.git" "/a/.git" "")
  it "reads the layout of a submodule" $
    GitOutput.parseLayout (separated ["/a/m\n", "/a/.git/modules/m\n", "/a/.git/modules/m\n"] <> "/a\n")
      `shouldBe` Just (Layout "/a/m" "/a/.git/modules/m" "/a/.git/modules/m" "/a")
  it "keeps newlines that belong to a path" $
    GitOutput.parseLayout (separated ["/with\nnewline\n", "/with\nnewline/.git\n", "/common\n\n"])
      `shouldBe` Just (Layout "/with\nnewline" "/with\nnewline/.git" "/common\n" "")
  it "rejects output with an unexpected number of fields" $ do
    GitOutput.parseLayout "/a\n" `shouldBe` Nothing
    GitOutput.parseLayout (separated ["/a\n", "/a\n", "/a\n", "/a\n"]) `shouldBe` Nothing
  it "reads a clean tracking branch" $
    GitOutput.parseSnapshot
      "# branch.oid 1a2b\n# branch.head main\n# branch.upstream origin/main\n# branch.ab +0 -0\n"
      `shouldBe` Snapshot Attached True False
  it "reads changes after the branch headers" $
    GitOutput.parseSnapshot
      "# branch.oid 1a2b\n# branch.head main\n# branch.upstream origin/main\n# branch.ab +? -?\n? x\n"
      `shouldBe` Snapshot Attached True True
  it "treats a configured upstream without a resolvable ref as untracked" $
    GitOutput.parseSnapshot "# branch.oid 1a2b\n# branch.head main\n# branch.upstream origin/main\n"
      `shouldBe` Snapshot Attached False False
  it "reads an unborn branch" $
    GitOutput.parseSnapshot "# branch.oid (initial)\n# branch.head main\n"
      `shouldBe` Snapshot Unborn False False
  it "reads a detached head" $
    GitOutput.parseSnapshot "# branch.oid 1a2b\n# branch.head (detached)\n"
      `shouldBe` Snapshot Detached False False

descriptorsSpec :: Spec
descriptorsSpec = describe "Descriptors.budget" $ do
  it "keeps a conventional limit for ordinary job counts" $ do
    Descriptors.budget 1 `shouldBe` 1024
    Descriptors.budget 16 `shouldBe` 1024
  it "grows with the job count so every concurrent child keeps its capture files" $
    Descriptors.budget 1000 `shouldBe` 4064
  it "does not overflow for the largest job count" $
    Descriptors.budget maxBound `shouldBe` 64 + 4 * toInteger (maxBound :: Int)
