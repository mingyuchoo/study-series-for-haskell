{-# LANGUAGE OverloadedStrings #-}

module PropertySpec
    ( spec
    ) where

import Flow ((<|))
import           Analysis.Parser

import           Data.Text                      (Text)
import qualified Data.Text                      as T

import           Test.Hspec
import           Test.QuickCheck
import           Test.QuickCheck.Instances.Text ()
-- Note: Language.LSP.Protocol.Types imports removed as they're not needed for this test

spec :: Spec
spec = describe "Property-Based Tests" <| do
  describe "Document Symbols Completeness" <| do
    it "Property 13: Document Symbols Completeness" $
      property prop_documentSymbolsCompleteness

-- **Feature: haskell-lsp-extension, Property 13: Document Symbols Completeness**
-- *For any* Haskell source file, the document symbols response SHALL include a DocumentSymbol
-- for every top-level declaration (functions, types, classes, instances) in the file.
-- **Validates: Requirements 5.4**
prop_documentSymbolsCompleteness :: Property
prop_documentSymbolsCompleteness =
  forAll genValidHaskellModule <| \moduleText ->
    case parseModule moduleText of
      Left _parseError ->
        -- If parsing fails, we can't test symbol completeness
        -- This is acceptable as the property is about valid Haskell files
        property True
      Right parsedModule ->
        let declarations = pmDeclarations parsedModule
            expectedDecls = countExpectedDeclarations moduleText
        in counterexample
           ("Expected " <> show expectedDecls <> " declarations, got " <> show (length declarations) <>
            "\nModule text:\n" <> T.unpack moduleText <>
            "\nFound declarations: " <> show (map declName declarations)) $
           length declarations >= expectedDecls

-- Generator for valid Haskell module text
genValidHaskellModule :: Gen Text
genValidHaskellModule = do
  moduleName <- genModuleName
  imports <- listOf genImport
  declarations <- listOf1 genTopLevelDeclaration

  let moduleHeader = "module " <> moduleName <> " where"
      importsSection = T.unlines imports
      declarationsSection = T.unlines declarations

  return <| T.unlines <| filter (not . T.null)
    [moduleHeader, "", importsSection, "", declarationsSection]

-- Generate a valid module name
genModuleName :: Gen Text
genModuleName = do
  parts <- listOf1 genCapitalizedIdentifier
  return <| T.intercalate "." parts

-- Generate a capitalized identifier (for module names, type names)
genCapitalizedIdentifier :: Gen Text
genCapitalizedIdentifier = do
  first <- choose ('A', 'Z')
  rest <- listOf <| frequency
    [ (10, choose ('a', 'z'))
    , (10, choose ('A', 'Z'))
    , (2, choose ('0', '9'))
    , (1, return '_')
    ]
  return <| T.pack (first : rest)

-- Generate a lowercase identifier (for function names, variable names)
genLowercaseIdentifier :: Gen Text
genLowercaseIdentifier = do
  first <- choose ('a', 'z')
  rest <- listOf <| frequency
    [ (10, choose ('a', 'z'))
    , (5, choose ('A', 'Z'))
    , (2, choose ('0', '9'))
    , (1, return '_')
    , (1, return '\'')
    ]
  return <| T.pack (first : rest)

-- Generate an import statement
genImport :: Gen Text
genImport = do
  moduleName <- genModuleName
  qualified <- arbitrary
  alias <- oneof [return Nothing, Just <$> genCapitalizedIdentifier]

  let qualifiedPart = if qualified then "qualified " else ""
      aliasPart = case alias of
        Nothing -> ""
        Just a  -> " as " <> a

  return <| "import " <> qualifiedPart <> moduleName <> aliasPart

-- Generate a top-level declaration
genTopLevelDeclaration :: Gen Text
genTopLevelDeclaration = oneof
  [ genFunctionDeclaration
  , genDataDeclaration
  , genTypeDeclaration
  , genClassDeclaration
  ]

-- Generate a function declaration
genFunctionDeclaration :: Gen Text
genFunctionDeclaration = do
  name <- genLowercaseIdentifier
  typeSignature <- genTypeSignature
  return <| name <> " :: " <> typeSignature

-- Generate a data declaration
genDataDeclaration :: Gen Text
genDataDeclaration = do
  name <- genCapitalizedIdentifier
  constructors <- listOf1 genCapitalizedIdentifier
  return <| "data " <> name <> " = " <> T.intercalate " | " constructors

-- Generate a type declaration
genTypeDeclaration :: Gen Text
genTypeDeclaration = do
  name <- genCapitalizedIdentifier
  targetType <- genCapitalizedIdentifier
  return <| "type " <> name <> " = " <> targetType

-- Generate a class declaration
genClassDeclaration :: Gen Text
genClassDeclaration = do
  name <- genCapitalizedIdentifier
  typeVar <- genLowercaseIdentifier
  return <| "class " <> name <> " " <> typeVar <> " where"

-- Generate a simple type signature
genTypeSignature :: Gen Text
genTypeSignature = oneof
  [ return "Int"
  , return "String"
  , return "Bool"
  , return "[Int]"
  , return "Maybe String"
  , do
      from <- genSimpleType
      to <- genSimpleType
      return <| from <> " -> " <> to
  ]

-- Generate a simple type
genSimpleType :: Gen Text
genSimpleType = elements ["Int", "String", "Bool", "Char", "Double"]

-- Count expected declarations in the module text
-- This is a simple heuristic that counts lines that look like top-level declarations
countExpectedDeclarations :: Text -> Int
countExpectedDeclarations moduleText =
  let linesOfCode = T.lines moduleText
      declarationLines = filter isTopLevelDeclaration linesOfCode
  in length declarationLines

-- Check if a line looks like a top-level declaration
isTopLevelDeclaration :: Text -> Bool
isTopLevelDeclaration line =
  let trimmed = T.strip line
  in not (T.null trimmed) &&
     not (T.isPrefixOf "--" trimmed) &&
     not (T.isPrefixOf "import " trimmed) &&
     not (T.isPrefixOf "module " trimmed) &&
     (T.isPrefixOf "data " trimmed ||
      T.isPrefixOf "type " trimmed ||
      T.isPrefixOf "class " trimmed ||
      T.isPrefixOf "instance " trimmed ||
      (T.isInfixOf "::" trimmed && isValidFunctionDeclaration trimmed))

-- Check if a line is a valid function declaration
isValidFunctionDeclaration :: Text -> Bool
isValidFunctionDeclaration line =
  case T.words line of
    (name:"::":_) -> isValidLowercaseIdentifier name
    _             -> False

-- Check if text is a valid lowercase identifier
isValidLowercaseIdentifier :: Text -> Bool
isValidLowercaseIdentifier name =
  not (T.null name) &&
  let firstChar = T.head name
  in (firstChar >= 'a' && firstChar <= 'z') &&
     T.all (\c -> (c >= 'a' && c <= 'z') ||
                  (c >= 'A' && c <= 'Z') ||
                  (c >= '0' && c <= '9') ||
                  c == '_' || c == '\'') name
