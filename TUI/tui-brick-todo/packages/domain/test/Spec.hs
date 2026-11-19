module Main (main) where

import Test.Hspec
import Todo.Domain.Model
import TodoStatus

main :: IO ()
main = hspec $ do
  describe "field validation" $ do
    it "rejects blank required actions" $
      validateFields " \t\n" Nothing Nothing Nothing `shouldBe` Left EmptyAction
    it "normalizes all fields and removes blank optional values" $ do
      let result = validateFields "  할 일  하기 " (Just "  나 ") (Just " \t ") Nothing
      fmap action result `shouldBe` Right "할 일 하기"
      fmap subject result `shouldBe` Right (Just "나")
      fmap indirectObject result `shouldBe` Right Nothing
  describe "status cycle" $ do
    it "cycles through all four statuses" $
      take 5 (iterate nextStatus Registered)
        `shouldBe` [Registered, InProgress, Cancelled, Completed, Registered]
    it "rejects unknown persisted statuses" $
      parseStatus "invalid" `shouldBe` Nothing
