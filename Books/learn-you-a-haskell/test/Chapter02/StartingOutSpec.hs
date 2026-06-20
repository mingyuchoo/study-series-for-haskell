module Chapter02.StartingOutSpec
  where

import Chapter02.StartingOut

import Test.Hspec

spec :: Spec
spec = do
  describe "Given `doubleMe` function" $ do
    let input = 2
        output = 4
    describe ("When input " ++ show input) $ do
      it ("returns " ++ show output) $ do
        doubleMe input `shouldBe` output

  describe "Given `doubleUs` function" $ do
    let input1 = 2
        input2 = 3
        output = 10
    describe ("When input " ++ show input1 ++ " " ++ show input2) $ do
      it ("returns " ++ show output) $ do
        doubleUs input1 input2 `shouldBe` output
