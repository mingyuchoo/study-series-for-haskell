module Main (main) where

import Fzh.Application.Ports (runWorkflow)
import Fzh.Application.Workflow (Workflow (..))
import Runtime (workflowPorts)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

main :: IO ()
main = do
  result <- runWorkflow workflowPorts
  case result of
    WorkflowFailed problem -> hPutStrLn stderr problem >> exitFailure
    _ -> pure ()
