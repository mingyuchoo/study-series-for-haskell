{-# LANGUAGE OverloadedStrings #-}

import Flow ((<|))
import Lib (withUserApplication)
import Network.HTTP.Types (status200)
import Network.Wai.Test
  ( defaultRequest
  , request
  , runSession
  , setPath
  , simpleBody
  , simpleStatus
  )
import Test.Hspec

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "Given Prelude" <| do
    context "when use `read` function" <| do
      it "should parse integers" <| do
        read "10" `shouldBe` (10 :: Int)
      it "should parse floating-point numbers" <| do
        read "2.5" `shouldBe` (2.5 :: Float)
  describe "GET /api/users" <| do
    it "returns an empty list for a fresh database" <| do
      withUserApplication ":memory:" $ \application -> do
        response <- runSession (request (setPath defaultRequest "/api/users")) application
        simpleStatus response `shouldBe` status200
        simpleBody response `shouldBe` "[]"
