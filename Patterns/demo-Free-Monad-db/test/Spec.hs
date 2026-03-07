-- {-# OPTIONS_GHC -F -pgmF doctest-discover #-}
-- {-# OPTIONS_GHC -F -pgmF hspec-discover   #-}

import Test.Hspec
import Lib
import System.IO.Silently (capture_)

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
    describe "Given Prelude" $ do
        context "when use `read` function" $ do
            it "should parse integers" $ do
                read "10" `shouldBe` (10 :: Int)
            it "should parse floating-point numbers" $ do
                read "2.5" `shouldBe` (2.5 :: Float)
    describe "Given Lib" $ do
        context "when use `runApp` with `program`" $ do
            it "should output log messages and user query result" $ do
                output <- capture_ someFunc
                output `shouldContain` "[FreeLog] Starting Free Monad app..."
                output `shouldContain` "Querying DB..."
                output `shouldContain` "[FreeLog] Got user: User_99"
        context "when use `logMsg`" $ do
            it "should output the given message" $ do
                output <- capture_ $ runApp (logMsg "hello")
                output `shouldContain` "[FreeLog] hello"
        context "when use `getUser`" $ do
            it "should return formatted user name" $ do
                output <- capture_ $ runApp $ do
                    user <- getUser 42
                    logMsg user
                output `shouldContain` "[FreeLog] User_42"
