module Main (main) where

import           Hfm.DevTools.Architecture (checkWorkspace)
import           Hfm.DevTools.Workspace    (readWorkspace)

import           System.Environment        (getArgs)
import           System.Exit               (exitFailure)
import           System.IO                 (hPutStrLn, stderr)

main :: IO ()
main = do
  arguments <- getArgs
  root <- case arguments of
    [] -> pure "."
    [path] -> pure path
    _ -> hPutStrLn stderr "Usage: hfm-check-architecture [WORKSPACE]" >> exitFailure
  violations <- checkWorkspace <$> readWorkspace root
  if null violations
    then putStrLn "Architecture boundaries passed: pure plans -> port interpreter; domain <- application <- adapters <- composition root"
    else mapM_ (hPutStrLn stderr) violations >> exitFailure
