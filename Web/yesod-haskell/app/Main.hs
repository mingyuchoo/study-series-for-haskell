-- | [REQ-F001] 애플리케이션 진입점
module Main
where

import Application (appMain)
import System.IO (hSetEncoding, stderr, stdout, utf8)

main :: IO ()
main = do
  hSetEncoding stdout utf8
  hSetEncoding stderr utf8
  appMain
