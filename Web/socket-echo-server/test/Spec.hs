-- {-# OPTIONS_GHC -F -pgmF doctest-discover #-}
-- {-# OPTIONS_GHC -F -pgmF hspec-discover   #-}

import Control.Concurrent (forkIO, killThread, threadDelay)
import Control.Exception (bracket)
import Lib
import Network.Socket qualified as Socket
import System.IO (IOMode (ReadWriteMode), hClose, hFlush, hGetLine, hPutStrLn)
import System.IO.Error (tryIOError)
import System.Timeout (timeout)
import Test.Hspec

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "Given Prelude" $ do
    context "when using `read` function" $ do
      it "should parse integers" $ do
        read "10" `shouldBe` (10 :: Int)
      it "should parse floating-point numbers" $ do
        read "2.5" `shouldBe` (2.5 :: Float)
  describe "Given Lib" $ do
    context "when using `someFunc` function" $ do
      it "should echo a line over TCP" $ do
        result <-
          timeout 5000000
            $ bracket (forkIO someFunc) killThread
            $ const echoResponse
        result `shouldBe` Just "You said: hello"

echoResponse :: IO String
echoResponse = do
  result <- bracket (Socket.socket Socket.AF_INET Socket.Stream 0) Socket.close $ \client -> do
    let address = Socket.SockAddrInet 8000 (Socket.tupleToHostAddress (127, 0, 0, 1))
    connected <- tryIOError (Socket.connect client address)
    case connected of
      Left _ -> pure Nothing
      Right () ->
        bracket (Socket.socketToHandle client ReadWriteMode) hClose $ \handle -> do
          hPutStrLn handle "hello"
          hFlush handle
          Just <$> hGetLine handle
  maybe (threadDelay 10000 >> echoResponse) pure result
