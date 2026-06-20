-- {-# OPTIONS_GHC -F -pgmF doctest-discover #-}
-- {-# OPTIONS_GHC -F -pgmF hspec-discover   #-}

import Lib
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
      it "should succeed" $ do
        someFunc
