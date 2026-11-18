{-# LANGUAGE OverloadedStrings #-}

import Database.SQLite.Simple (withConnection)
import Flow ((<|))
import Lib (app)
import Network.HTTP.Types (status400)
import Network.Wai (defaultRequest)
import Network.Wai.Test (request, runSession, setPath, simpleStatus)

-- {-# OPTIONS_GHC -F -pgmF doctest-discover #-}
-- {-# OPTIONS_GHC -F -pgmF hspec-discover   #-}

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
  describe "GET /api/users/:id" <| do
    it "returns a bad request for an invalid user ID" <| do
      withConnection ":memory:" <| \connection -> do
        response <-
          runSession (request (setPath defaultRequest "/api/users/invalid")) (app connection)
        simpleStatus response `shouldBe` status400
