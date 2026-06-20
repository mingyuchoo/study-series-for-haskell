module Lib
  ( someFunc
  ) where

import Network.Socket

import System.IO

someFunc :: IO ()
someFunc = do
  sock <- socket AF_INET Stream 0
  setSocketOption sock ReuseAddr 1
  bind sock (SockAddrInet 8000 0)
  listen sock 2
  putStrLn "Listening on port 8000..."
  mainLoop sock

mainLoop :: Socket -> IO ()
mainLoop sock = do
  (conn, _) <- accept sock
  handler conn
  mainLoop sock

handler :: Socket -> IO ()
handler conn = do
  handleSock <- socketToHandle conn ReadWriteMode
  line <- hGetLine handleSock
  putStrLn $ "Client says: " ++ line
  hPutStrLn handleSock $ "You said: " ++ line
  hClose handleSock
