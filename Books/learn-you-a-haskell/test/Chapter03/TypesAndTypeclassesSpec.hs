module Chapter03.TypesAndTypeclassesSpec
  where

import Chapter03.TypesAndTypeclasses

import Test.Hspec

spec :: Spec
spec = do
  describe "Given `removeNonUppercase` function`" $ do
    let input = "Hello, Haskell!"
        output = "HH"
    describe ("When input " ++ show input) $ do
      it ("returns " ++ output) $ do
        removeNonUppercase "Hello, Haskell!" `shouldBe` "HH"

  describe "Given `addThree` function" $ do
    let input1 = (-1)
        input2 = (-2)
        input3 = 3
        output = 0
    describe ("When input (" ++ show input1 ++ ") (" ++ show input2 ++ ") " ++ show input3) $ do
      it ("returns " ++ show output) $ do
        addThree input1 input2 input3 `shouldBe` output

  describe "Given `circumference` function" $ do
    let input = 4.0
        output = 25.132741228718345
    describe ("When input " ++ show input) $ do
      it ("returns " ++ show output) $ do
        circumference input `shouldBe` output
