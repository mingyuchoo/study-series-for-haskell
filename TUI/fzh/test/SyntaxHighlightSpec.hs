{-# LANGUAGE OverloadedStrings #-}

module SyntaxHighlightSpec (spec) where

import Test.Hspec
import SyntaxHighlight
import qualified Data.Text as T
import Data.Maybe (isJust)

spec :: Spec
spec = do
  describe "detectLanguage" $ do
    it "detects Haskell files" $ do
      detectLanguage "test.hs" `shouldSatisfy` isJust

    it "detects Python files" $ do
      detectLanguage "test.py" `shouldSatisfy` isJust

    it "detects JavaScript files" $ do
      detectLanguage "test.js" `shouldSatisfy` isJust

    it "returns Nothing for unknown extensions" $ do
      detectLanguage "test.unknown" `shouldBe` Nothing

    it "returns Nothing for files without extensions" $ do
      detectLanguage "README" `shouldBe` Nothing

  describe "renderPlainText" $ do
    it "creates a widget from text lines" $ do
      let lines = ["line 1", "line 2", "line 3"]
      let widget = renderPlainText lines
      -- Widget이 생성되는지만 확인 (타입 체크)
      widget `seq` True `shouldBe` True

  describe "limitLines" $ do
    it "limits content to 100 lines" $ do
      let content = T.unlines $ map (T.pack . show) [1..200]
      length (limitLines content) `shouldBe` 100

    it "preserves content with less than 100 lines" $ do
      let content = T.unlines $ map (T.pack . show) [1..50]
      length (limitLines content) `shouldBe` 50
