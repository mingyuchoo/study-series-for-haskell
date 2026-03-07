module Lib
    ( cliMain
    ) where

import           LSP.Server  (runLspServer)

import           System.Exit (ExitCode (..), exitWith)

cliMain :: IO ()
cliMain = do
  exitCode <- runLspServer
  exitWith <| case exitCode of
    0 -> ExitSuccess
    n -> ExitFailure n
  where
    (<|) = ($)
