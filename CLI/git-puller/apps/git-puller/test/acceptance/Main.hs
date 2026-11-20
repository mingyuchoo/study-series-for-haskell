module Main
  ( main
  ) where

import System.Directory (findExecutable)
import System.Exit (die)
import System.Process (callProcess)

main :: IO ()
main = do
  located <- findExecutable "git-puller"
  case located of
    Nothing         -> die "git-puller executable not found on PATH"
    Just executable -> callProcess "bash" ["test/cli.sh", executable]
