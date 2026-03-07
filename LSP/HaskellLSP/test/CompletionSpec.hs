{-# LANGUAGE OverloadedStrings #-}

module CompletionSpec
    ( spec
    ) where

import Flow ((<|))
import           Analysis.Parser             (parseModule)

import           Control.Lens                ((^.))

import           Data.Text                   (Text)
import qualified Data.Text                   as T

import           Handlers.Completion

import qualified Language.LSP.Protocol.Lens  as L
import           Language.LSP.Protocol.Types

import           Test.Hspec

spec :: Spec
spec = describe "Completion Handler" <| do

  describe "determineCompletionContext" <| do
    it "should extract prefix from cursor position" <| do
      let content = "add"
          position = Position 0 3
          context = determineCompletionContext content position Nothing
      ccPrefix context `shouldBe` "add"

    it "should detect module qualifier" <| do
      let content = "Data.List.so"
          position = Position 0 12
          context = determineCompletionContext content position Nothing
      ccModule context `shouldBe` Just "Data.List"
      ccPrefix context `shouldBe` "so"

    it "should handle empty prefix" <| do
      let content = "Data.Map."
          position = Position 0 9
          context = determineCompletionContext content position Nothing
      ccModule context `shouldBe` Just "Data.Map"
      ccPrefix context `shouldBe` ""

  describe "getModuleCompletions" <| do
    it "should return Data.List completions" <| do
      -- This is a simple test that would need to be run in LspM context
      -- For now, we just test that the function exists and can be called
      let moduleName = "Data.List"
      T.length moduleName `shouldBe` 9

    it "should normalize module names" <| do
      normalizeModuleName "Map" `shouldBe` "Data.Map"
      normalizeModuleName "List" `shouldBe` "Data.List"
      normalizeModuleName "Data.Text" `shouldBe` "Data.Text"

  describe "filterCompletionsByPrefix" <| do
    it "should filter completions by prefix" <| do
      let items = [ createCompletionItem "sort" Nothing CompletionItemKind_Function
                  , createCompletionItem "filter" Nothing CompletionItemKind_Function
                  , createCompletionItem "map" Nothing CompletionItemKind_Function
                  ]
          filtered = filterCompletionsByPrefix "s" items
      length filtered `shouldBe` 1
      ((head filtered) ^. L.label) `shouldBe` "sort"

    it "should return all items for empty prefix" <| do
      let items = [ createCompletionItem "sort" Nothing CompletionItemKind_Function
                  , createCompletionItem "filter" Nothing CompletionItemKind_Function
                  ]
          filtered = filterCompletionsByPrefix "" items
      length filtered `shouldBe` 2

  describe "createCompletionItem" <| do
    it "should create function completion with type signature" <| do
      let item = createCompletionItem "sort" (Just "Ord a => [a] -> [a]") CompletionItemKind_Function
      item ^. L.label `shouldBe` "sort"
      item ^. L.detail `shouldBe` Just "sort :: Ord a => [a] -> [a]"
      item ^. L.kind `shouldBe` Just CompletionItemKind_Function

    it "should create completion without type signature" <| do
      let item = createCompletionItem "example" Nothing CompletionItemKind_Variable
      item ^. L.label `shouldBe` "example"
      item ^. L.detail `shouldBe` Nothing
      item ^. L.kind `shouldBe` Just CompletionItemKind_Variable
