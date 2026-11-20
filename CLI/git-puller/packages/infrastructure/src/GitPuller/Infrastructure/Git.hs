module GitPuller.Infrastructure.Git (
  childEnvironment,
  check,
  inspectRepository,
  pull,
)
where

import Control.Exception (try)
import Control.Monad (void, when)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT (..), runExceptT, throwE, withExceptT)
import GitPuller.Domain.Repository (Branch (..), Inspection (..), Operation (..), State (..))
import GitPuller.Infrastructure.Failure qualified as Failure
import GitPuller.Infrastructure.Filesystem (PathKind (Missing, Symlink, Unavailable), pathKind)
import GitPuller.Infrastructure.GitOutput (Layout (..))
import GitPuller.Infrastructure.GitOutput qualified as GitOutput
import GitPuller.Infrastructure.Process (CompletedProcess (..))
import GitPuller.Infrastructure.Process qualified as Process
import System.Directory (canonicalizePath)
import System.Environment (getEnvironment)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))

type Git = ExceptT String IO

childEnvironment :: [(String, String)] -> [(String, String)]
childEnvironment environment =
  filter ((`notElem` overridden) . fst) environment
    <> [("GIT_TERMINAL_PROMPT", "0"), ("GIT_OPTIONAL_LOCKS", "0")]
 where
  overridden =
    [ "GIT_ALTERNATE_OBJECT_DIRECTORIES"
    , "GIT_CONFIG"
    , "GIT_CONFIG_PARAMETERS"
    , "GIT_CONFIG_COUNT"
    , "GIT_OBJECT_DIRECTORY"
    , "GIT_DIR"
    , "GIT_WORK_TREE"
    , "GIT_IMPLICIT_WORK_TREE"
    , "GIT_GRAFT_FILE"
    , "GIT_INDEX_FILE"
    , "GIT_NO_REPLACE_OBJECTS"
    , "GIT_REPLACE_REF_BASE"
    , "GIT_PREFIX"
    , "GIT_INTERNAL_SUPER_PREFIX"
    , "GIT_SHALLOW_FILE"
    , "GIT_COMMON_DIR"
    , "GIT_QUARANTINE_PATH"
    , "GIT_NAMESPACE"
    , "GIT_TERMINAL_PROMPT"
    , "GIT_OPTIONAL_LOCKS"
    ]

run :: [String] -> Git CompletedProcess
run arguments = do
  environment <- liftIO getEnvironment
  ExceptT (Process.run "git" arguments (childEnvironment environment))

runIn :: FilePath -> [String] -> Git CompletedProcess
runIn worktree arguments = run ("-C" : worktree : arguments)

failure :: CompletedProcess -> String
failure completed
  | not (null (diagnostic completed)) = diagnostic completed
  | otherwise = case status completed of
      ExitFailure code | code > 0 -> "Git exited with status " <> show code
      _ -> "Git terminated by a signal"

successful :: CompletedProcess -> Git String
successful completed = case status completed of
  ExitSuccess -> pure (output completed)
  ExitFailure _ -> throwE (failure completed)

withoutNewline :: String -> String
withoutNewline text = case reverse text of
  '\n' : reversed -> reverse reversed
  _ -> text

readIn :: FilePath -> [String] -> Git String
readIn worktree arguments = runIn worktree arguments >>= successful

operationPresent :: FilePath -> FilePath -> String -> Git Bool
operationPresent worktree metadata marker = do
  kind <- liftIO (pathKind (metadata </> marker))
  case kind of
    Missing -> pure False
    Symlink -> resolved
    Unavailable -> resolved
    _ -> pure True
 where
  resolved = do
    location <-
      withoutNewline <$> readIn worktree ["rev-parse", "--path-format=absolute", "--git-path", marker]
    kind <- liftIO (pathKind location)
    case kind of
      Missing -> pure False
      Unavailable -> throwE ("cannot inspect Git state at " <> show location)
      _ -> pure True

currentOperation :: FilePath -> FilePath -> Git Operation
currentOperation worktree metadata = do
  merging <- present "MERGE_HEAD"
  if merging
    then pure Merge
    else do
      rebasing <- present "rebase-merge" `orElse` present "rebase-apply"
      pure (if rebasing then Rebase else Idle)
 where
  present = operationPresent worktree metadata
  orElse first second = first >>= \found -> if found then pure True else second

inspectState :: FilePath -> FilePath -> Git State
inspectState worktree metadata = do
  snapshot <- GitOutput.parseSnapshot <$> readIn worktree GitOutput.snapshotArguments
  current <- case GitOutput.branch snapshot of
    Unborn -> pure Idle
    Detached -> currentOperation worktree metadata
    Attached -> currentOperation worktree metadata
  pure
    State
      { branch = GitOutput.branch snapshot
      , operation = current
      , upstream = GitOutput.tracking snapshot
      , dirty = GitOutput.changed snapshot
      }

readLayout :: FilePath -> Git Layout
readLayout worktree = do
  described <- readIn worktree GitOutput.layoutArguments
  maybe (throwE "cannot read Git repository layout") pure (GitOutput.parseLayout described)

check :: IO (Either String ())
check = runExceptT (void (run ["--version"] >>= successful))

inspectRepository :: FilePath -> IO (Either String Inspection)
inspectRepository worktree = runExceptT $ do
  layout <- readLayout worktree
  when (toplevel layout /= worktree) (throwE "Git worktree root does not match candidate")
  if null (superproject layout)
    then do
      shared <- withExceptT Failure.reason (ExceptT (try (canonicalizePath (commonDirectory layout))))
      Standalone shared <$> inspectState worktree (gitDirectory layout)
    else pure Nested

pull :: FilePath -> IO (Either String ())
pull worktree =
  runExceptT . void $
    runIn worktree ["pull", "--ff-only", "--no-rebase", "--no-recurse-submodules"] >>= successful
