module ExampleHspec
  where

import Control.Exception (evaluate)

import Test.Hspec
import Test.QuickCheck

call :: IO ()
call = hspec $ do
  describe "Given Prelude" $ do
    context "when use read" $ do
      it "can parse integers" $ do
        read "10" `shouldBe` (10 :: Int)
      it "can parse floating-point numbers" $ do
        read "2.5" `shouldBe` (2.5 :: Float)
    context "when use head" $ do
      it "returns the first element of a list" $ do
        head [23 ..] `shouldBe` (23 :: Int)
      it "returns the first element of a *arbitrary* list" $ do
        property $ \x xs -> head (x : xs) == (x :: Int)
      it "throws an exception if used with an empty list" $ do
        evaluate (head []) `shouldThrow` anyException
