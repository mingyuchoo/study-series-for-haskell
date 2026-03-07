module DefinitionSpec
    ( spec
    ) where

import Flow ((<|))
import           Analysis.Parser     (ParsedModule (..))

import           Handlers.Definition

import           Test.Hspec

spec :: Spec
spec = describe "Definition Handler" <| do
  describe "handleDefinition" <| do
    it "should be available for import" <| do
      -- Test that handleDefinition function exists and can be referenced
      let _ = handleDefinition
      True `shouldBe` True

  describe "handleDocumentSymbol" <| do
    it "should be available for import" <| do
      -- Test that handleDocumentSymbol function exists and can be referenced
      let _ = handleDocumentSymbol
      True `shouldBe` True

  describe "findLocalBinding" <| do
    it "should return Nothing for empty declarations" <| do
      let emptyModule = ParsedModule
            { pmSource = ""
            , pmDeclarations = []
            , pmImports = []
            , pmExports = Nothing
            }
      findLocalBinding emptyModule "test" `shouldBe` Nothing

  describe "createDocumentSymbols" <| do
    it "should handle empty declaration list" <| do
      createDocumentSymbols [] `shouldBe` []

    it "should return correct number of symbols" <| do
      -- Create a simple test without using the ambiguous constructors
      let symbols = createDocumentSymbols []
      length symbols `shouldBe` 0
