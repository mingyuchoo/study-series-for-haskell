module Main
  ( main
  ) where

import Data.Kind

import Lib

import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  startApp
