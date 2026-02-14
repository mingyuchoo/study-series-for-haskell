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
