{-# LANGUAGE UnicodeSyntax #-}

module Chapter2Spec
  ( spec
  ) where

import Chapter2

import Test.Hspec

-- | spec
spec :: Spec
spec = do
  describe "firstOrEmpty" $ do
    it "firstOrEmpty [] should be []" $ do
      firstOrEmpty [] `shouldBe` "empty"

    it "firstOrEmpty [\"hello\",\"hola\"] should be \"hello\"" $ do
      firstOrEmpty ["hello", "hola"] `shouldBe` "hello"
