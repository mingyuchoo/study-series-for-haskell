module Chapter04.SyntaxInFunctionsSpec
  where

import Chapter04.SyntaxInFunctions

import Test.Hspec

spec :: Spec
spec = do
  describe "Gvien `lucky` function" $ do
    let input = 7
        output = "LUCKY NUMBER SEVEN!"
    describe ("When input " ++ show input) $ do
      it ("returns " ++ output) $ do
        lucky input `shouldBe` output

    let input = 1
        output = "Sorry, you're out of luck, pal!"
    describe ("When input " ++ show input) $ do
      it ("returns " ++ output) $ do
        lucky input `shouldBe` output

  describe "Given `sayMe` function" $ do
    let input = 1
        output = "One!"
    describe ("When input " ++ show input) $ do
      it ("returns " ++ output) $ do
        sayMe input `shouldBe` output

    let input = 5
        output = "Five!"
    describe ("When input " ++ show input) $ do
      it ("returns " ++ output) $ do
        sayMe input `shouldBe` output

    let input = 9
        output = "Not between 1 and 5"
    describe ("When input " ++ show input) $ do
      it ("returns " ++ output) $ do
        sayMe input `shouldBe` output
