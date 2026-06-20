module Main
    ( main
    ) where

import qualified Infrastructure.Web.Server as Server

import           System.Environment        (getArgs)
import           System.IO                 (BufferMode (NoBuffering),
                                            hSetBuffering, stdout)

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  args <- getArgs
  choose args
  where
    choose :: [String] -> IO ()
    choose [] = putStrLn "Running Basic Server" >> Server.runBasicServer
    choose (a : _)
      | a == "cache" = putStrLn "Running Cache Server" >> Server.runCachedServer
      | otherwise = putStrLn "Running Esqueleto Server" >> Server.runEsqueletoServer
