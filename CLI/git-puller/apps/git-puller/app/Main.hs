module Main (main) where

import Control.Monad (unless, when)
import Data.Foldable (traverse_)
import Data.IORef (IORef, modifyIORef', newIORef, readIORef)
import GitPuller.Application.Ports (Event (..), Ports (..))
import GitPuller.Cli.Arguments (Command (..), Options (..))
import GitPuller.Cli.Arguments qualified as Arguments
import GitPuller.Cli.Render qualified as Render
import GitPuller.Domain.Outcome (Outcome)
import GitPuller.Domain.Outcome qualified as Outcome
import GitPuller.Infrastructure.BatchRunner qualified as BatchRunner
import GitPuller.Infrastructure.Encoding qualified as Encoding
import GitPuller.Infrastructure.Filesystem qualified as Filesystem
import GitPuller.Infrastructure.Git qualified as Git
import GitPuller.Infrastructure.Terminal (Terminal (..))
import GitPuller.Infrastructure.Terminal qualified as Terminal
import System.Environment (getArgs)
import System.Exit (ExitCode (..), exitWith)
import System.IO (hPutStrLn, stderr)

data Progress = Progress
  { discovered :: Int
  , completed :: Int
  , total :: Int
  }

reporter :: Bool -> Terminal -> IORef Progress -> Event -> IO ()
reporter isVerbose terminal state event = case event of
  Scanning -> scan
  Discovered -> advance (\current -> current{discovered = discovered current + 1}) >> scan
  Processing count -> advance (\current -> current{total = count}) >> processed
  Inspecting location -> narrate ("Inspecting " <> Render.quoted location)
  Pulling location -> narrate ("Pulling " <> Render.quoted location)
  Processed result -> do
    narrate (Render.outcome isVerbose result)
    advance (\current -> current{completed = completed current + 1})
    processed
 where
  advance = modifyIORef' state
  narrate text = when isVerbose (writeLine terminal text)
  scan = do
    current <- readIORef state
    writeProgress terminal ("Scanning: " <> show (discovered current) <> " repositories found")
  processed = do
    current <- readIORef state
    writeProgress terminal (Render.progress (completed current) (total current))

startupError :: String -> IO ExitCode
startupError diagnostic = ExitFailure 2 <$ hPutStrLn stderr diagnostic

runBatch :: Options -> FilePath -> (Event -> IO ()) -> IO [Outcome]
runBatch options root reportEvent =
  BatchRunner.run ports (jobs options) (mode options) root
 where
  ports =
    Ports
      { listDirectory = Filesystem.listDirectory
      , inspectRepository = Git.inspectRepository
      , locateCommonDirectory = Git.locateCommonDirectory
      , pull = Git.pull
      , report = reportEvent
      }

update :: Options -> FilePath -> IO ExitCode
update options root = do
  interactive <- Terminal.isInteractive
  outcomes <-
    if interactive || verbose options
      then Terminal.withProgress interactive $ \terminal -> do
        state <- newIORef (Progress 0 0 0)
        runBatch options root (reporter (verbose options) terminal state)
      else runBatch options root (const (pure ()))
  unless (verbose options) (traverse_ (putStrLn . Render.outcome False) outcomes)
  when (null outcomes) (putStrLn "No Git worktrees found.")
  putStrLn (Render.summary outcomes)
  pure
    (if Outcome.exitCode outcomes == 0 then ExitSuccess else ExitFailure (Outcome.exitCode outcomes))

run :: Options -> IO ExitCode
run options = do
  normalized <- Filesystem.normalizeRoot (path options)
  case normalized of
    Left diagnostic -> startupError (Render.quoted (path options) <> " " <> diagnostic)
    Right root -> do
      available <- Git.check
      case available of
        Left diagnostic -> startupError ("Cannot run Git. " <> diagnostic)
        Right () -> update options root

execute :: [String] -> IO ExitCode
execute arguments = case Arguments.parse arguments of
  Left diagnostic -> startupError (diagnostic <> "\n" <> Arguments.usage)
  Right Help -> ExitSuccess <$ putStrLn Arguments.usage
  Right (Run options) -> run options

main :: IO ()
main = do
  Encoding.useLosslessUtf8
  getArgs >>= execute >>= exitWith
