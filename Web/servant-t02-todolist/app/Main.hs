module Main
  ( main
  ) where

-- -------------------------------------------------------------------
-- Imports
-- -------------------------------------------------------------------

import Lib

import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)

-- -------------------------------------------------------------------
-- Application
-- -------------------------------------------------------------------

-- Main function

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  appRunner
