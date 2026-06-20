module Main
  ( main
  ) where

import Network.Wai.Handler.Warp (run)
import Order
import OrderAPI
import Servant
import Server
import System.IO (BufferMode (NoBuffering), hSetBuffering, stdout)

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  putStrLn "서버 실행 중: http://localhost:8080/order"
  run 8080 (serve api server)
