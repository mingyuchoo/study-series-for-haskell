{-# LANGUAGE OverloadedStrings #-}

module SyntaxHighlightSpec
    ( spec
    ) where

import           Data.Maybe      (isJust)
import qualified Data.Text       as T

import Brick (attrName, attrMapLookup, padRight, padBottom, Padding (Max))
import Brick.Main (renderWidget)
import qualified Data.Text.Lazy as TL
import qualified Data.Vector as Vec
import qualified Graphics.Vty as V
import Graphics.Vty.PictureToSpans (displayOpsForPic)
import Graphics.Vty.Span (SpanOp (..))
import Hfm.Domain.Theme (themes)
import Hfm.Tui.Theme (themeAttributes)
import Hfm.Tui.Text (expandTabs)
import           Hfm.Tui.SyntaxHighlight

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
      -- Widget이 생성되는지만 확인 (타입 체크)
      widget `seq` True `shouldBe` True

  describe "limitLines" $ do
    it "limits content to 100 lines" $ do
      let content = T.unlines $ map (T.pack . show) [1 .. 200 :: Int]
      length (limitLines content) `shouldBe` 100

    it "preserves content with less than 100 lines" $ do
      let content = T.unlines $ map (T.pack . show) [1 .. 50 :: Int]
      length (limitLines content) `shouldBe` 50

  describe "Display-cell tab expansion" $ do
    it "keeps tab stops after wide and combining characters and resets on each line" $ do
      expandTabs "가\t값\ne\x0301\tvalue" `shouldBe` "가      값\ne\x0301       value"
      expandTabs "12345678\tend" `shouldBe` "12345678        end"

  describe "Syntax and plain-text tab rendering" $ do
    it "paints tabs across token boundaries with every theme's background" $ do
      mapM_ (\(theme, path) -> do
        let attributes = themeAttributes theme
            background = V.attrBackColor (attrMapLookup (attrName "default") attributes)
            widget = padRight Max $ padBottom Max $ renderHighlightedContent path "main =\tputStrLn \"x\tz\""
            ops = displayOpsForPic (renderWidget (Just attributes) [widget] (80, 4)) (80, 4)
            spans = concatMap Vec.toList (Vec.toList ops)
            text (TextSpan _ _ _ value) = TL.toStrict value
            text (Skip count) = T.replicate count " "
            text (RowEnd count) = T.replicate count " "
            firstLine = T.concat (map text (Vec.toList (Vec.head ops)))
        firstLine `shouldSatisfy` T.isPrefixOf "  1 | main =  putStrLn \"x     z\""
        mapM_ (\op -> case op of
          TextSpan attribute _ _ value -> do
            V.attrBackColor attribute `shouldBe` background
            TL.any (== '\t') value `shouldBe` False
          _ -> pure ()) spans) [(theme, path) | theme <- themes, path <- ["test.hs", "test.unknown"]]
