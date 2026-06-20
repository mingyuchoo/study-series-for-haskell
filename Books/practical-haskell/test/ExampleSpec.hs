{-# LANGUAGE UnicodeSyntax #-}

module ExampleSpec
  ( spec
  ) where

import Test.Hspec

-- | spec
spec :: Spec
spec = do
  describe "Example" $ do
    it "1 + 1 = 2" $ do
      1 + 1 `shouldBe` 2
