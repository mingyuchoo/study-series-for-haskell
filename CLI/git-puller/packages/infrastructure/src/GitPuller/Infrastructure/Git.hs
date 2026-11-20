module GitPuller.Infrastructure.Git (
  childEnvironment,
  check,
  inspectRepository,
  locateCommonDirectory,
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
readIn worktree arguments = withoutNewline <$> (runIn worktree arguments >>= successful)

refExists :: FilePath -> [String] -> Git Bool
refExists worktree arguments = do
  completed <- runIn worktree arguments
  case status completed of
    ExitSuccess -> pure True
    ExitFailure 1 -> pure False
    ExitFailure _ -> throwE (failure completed)

operationPresent :: FilePath -> FilePath -> String -> Git Bool
operationPresent worktree gitDirectory marker = do
  kind <- liftIO (pathKind (gitDirectory </> marker))
  case kind of
    Missing -> pure False
    Symlink -> resolved
    Unavailable -> resolved
    _ -> pure True
 where
  resolved = do
    location <- readIn worktree ["rev-parse", "--path-format=absolute", "--git-path", marker]
    kind <- liftIO (pathKind location)
    case kind of
      Missing -> pure False
      Unavailable -> throwE ("cannot inspect Git state at " <> show location)
      _ -> pure True

currentOperation :: FilePath -> Git Operation
currentOperation worktree = do
  gitDirectory <- readIn worktree ["rev-parse", "--absolute-git-dir"]
  let present = operationPresent worktree gitDirectory
  merging <- present "MERGE_HEAD"
  if merging
    then pure Merge
    else do
      rebasing <- present "rebase-merge" `orElse` present "rebase-apply"
      pure (if rebasing then Rebase else Idle)
 where
  orElse first second = first >>= \found -> if found then pure True else second

inspectState :: FilePath -> Git State
inspectState worktree = do
  born <- refExists worktree ["rev-parse", "--verify", "--quiet", "HEAD"]
  if not born
    then pure State{branch = Unborn, operation = Idle, upstream = False, dirty = False}
    else do
      current <- currentOperation worktree
      attached <- refExists worktree ["symbolic-ref", "--quiet", "HEAD"]
      if not attached
        then pure State{branch = Detached, operation = current, upstream = False, dirty = False}
        else do
          tracking <- refExists worktree ["rev-parse", "--verify", "--quiet", "@{upstream}"]
          changes <-
            readIn
              worktree
              [ "status"
              , "--porcelain=v1"
              , "--untracked-files=normal"
              , "--ignore-submodules=none"
              ]
          pure
            State
              { branch = Attached
              , operation = current
              , upstream = tracking
              , dirty = not (null changes)
              }

check :: IO (Either String ())
check = runExceptT (void (run ["--version"] >>= successful))

inspectRepository :: FilePath -> IO (Either String Inspection)
inspectRepository worktree = runExceptT $ do
  root <- readIn worktree ["rev-parse", "--show-toplevel"]
  when (root /= worktree) (throwE "Git worktree root does not match candidate")
  superproject <- readIn worktree ["rev-parse", "--show-superproject-working-tree"]
  if null superproject
    then Standalone <$> inspectState worktree
    else pure Nested

locateCommonDirectory :: FilePath -> IO (Either String FilePath)
locateCommonDirectory worktree = runExceptT $ do
  directory <- readIn worktree ["rev-parse", "--path-format=absolute", "--git-common-dir"]
  withExceptT Failure.reason (ExceptT (try (canonicalizePath directory)))

pull :: FilePath -> IO (Either String ())
pull worktree =
  runExceptT . void $
    runIn worktree ["pull", "--ff-only", "--no-rebase", "--no-recurse-submodules"] >>= successful
