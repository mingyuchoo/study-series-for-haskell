{-# LANGUAGE OverloadedStrings #-}

module SyntaxHighlightSpec
    ( spec
    ) where

import           Data.Maybe      (isJust)
import qualified Data.Text       as T

import           SyntaxHighlight

import           Test.Hspec

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
      let textLines = ["line 1", "line 2", "line 3"]
      let widget = renderPlainText textLines
      widget `seq` True `shouldBe` True

  describe "limitLines" $ do
    it "limits String preview conversion before touching content beyond the visible lines" $ do
      let content = unlines (replicate 100 "visible") ++ error "read beyond preview limit"
      limitStringLines content `shouldBe` replicate 100 "visible"
    it "limits content to 100 lines" $ do
      let content = T.unlines $ map (T.pack . show) [1 :: Int .. 200]
      length (limitLines content) `shouldBe` 100

    it "preserves content with less than 100 lines" $ do
      let content = T.unlines $ map (T.pack . show) [1 :: Int .. 50]
      length (limitLines content) `shouldBe` 50
