{-# LANGUAGE LambdaCase #-}

module HoverSpec
    ( spec
    ) where

import Flow ((<|))
import           Analysis.Parser

import           Data.Text                   (Text)
import qualified Data.Text                   as T

import           Handlers.Hover

import           Language.LSP.Protocol.Types

import           Test.Hspec

spec :: Spec
spec = describe "Hover Handler" <| do
  describe "formatHoverContent" <| do
    it "should format function hover with type signature" <| do
      let symbolInfo = SymbolInfo
            { symName = "add"
            , symType = Just "Int -> Int -> Int"
            , symKind = SymbolKind_Function
            , symLocation = Location (read "\"file:///test.hs\"") (Range (Position 0 0) (Position 0 3))
            , symDocumentation = Just "Adds two integers"
            }
      let result = formatHoverContent symbolInfo
      result `shouldSatisfy` \case
        Just content ->
          "```haskell" `T.isInfixOf` content &&
          "add :: Int -> Int -> Int" `T.isInfixOf` content &&
          "Adds two integers" `T.isInfixOf` content
        Nothing -> False

    it "should format type hover" <| do
      let symbolInfo = SymbolInfo
            { symName = "Person"
            , symType = Nothing
            , symKind = SymbolKind_Struct
            , symLocation = Location (read "\"file:///test.hs\"") (Range (Position 0 0) (Position 0 6))
            , symDocumentation = Nothing
            }
      let result = formatHoverContent symbolInfo
      result `shouldSatisfy` \case
        Just content ->
          "```haskell" `T.isInfixOf` content &&
          "data Person" `T.isInfixOf` content
        Nothing -> False

    it "should format operator hover with type and fixity" <| do
      let symbolInfo = SymbolInfo
            { symName = "+"
            , symType = Just "Num a => a -> a -> a"
            , symKind = SymbolKind_Function
            , symLocation = Location (read "\"file:///test.hs\"") (Range (Position 0 0) (Position 0 1))
            , symDocumentation = Just "Addition operator"
            }
      let result = formatHoverContent symbolInfo
      result `shouldSatisfy` \case
        Just content ->
          "```haskell" `T.isInfixOf` content &&
          "(+) :: Num a => a -> a -> a" `T.isInfixOf` content &&
          "Fixity information not available" `T.isInfixOf` content &&
          "Addition operator" `T.isInfixOf` content
        Nothing -> False

    it "should return something for unsupported symbol kinds" <| do
      let symbolInfo = SymbolInfo
            { symName = "unknown"
            , symType = Nothing
            , symKind = SymbolKind_Null  -- Unsupported kind
            , symLocation = Location (read "\"file:///test.hs\"") (Range (Position 0 0) (Position 0 7))
            , symDocumentation = Nothing
            }
      let result = formatHoverContent symbolInfo
      -- Should still return something for generic hover
      result `shouldSatisfy` \case
        Just content -> "```haskell" `T.isInfixOf` content
        Nothing -> False

  describe "hover integration" <| do
    it "should handle sample Haskell code" <| do
      let sampleCode = T.unlines
            [ "module Sample where"
            , ""
            , "add :: Int -> Int -> Int"
            , "add x y = x + y"
            ]
      case parseModule sampleCode of
        Left _err -> expectationFailure "Failed to parse sample code"
        Right parsedModule -> do
          -- Test resolving symbol at position of 'add' function
          let position = Position 2 0  -- Line 2, character 0 (where 'add' starts)
          case resolveSymbol parsedModule position of
            Nothing -> expectationFailure "Failed to resolve symbol"
            Just symbolInfo -> do
              symName symbolInfo `shouldBe` "add"
              symKind symbolInfo `shouldBe` SymbolKind_Function
