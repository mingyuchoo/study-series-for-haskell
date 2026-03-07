{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Haskell code analysis and parsing module
module Analysis.Parser
    ( Declaration (..)
    , Export (..)
    , Import (..)
    , ParseError (..)
    , ParsedModule (..)
    , SymbolInfo (..)
    , parseModule
    , printModule
    , resolveSymbol
    , symbolsInScope
    ) where

import           Data.Char                   (isAlpha, isAlphaNum)
import           Data.Text                   (Text)
import qualified Data.Text                   as T

import           Flow                        ((<|))

import           GHC.Generics                (Generic)

import           Language.LSP.Protocol.Types (Location (..), Position (..),
                                              Range (..), SymbolKind (..), Uri)


-- | Parsed Haskell module representation
data ParsedModule = ParsedModule { pmSource       :: Text
                                 , pmDeclarations :: [Declaration]
                                 , pmImports      :: [Import]
                                 , pmExports      :: Maybe [Export]
                                 }
     deriving (Eq, Generic, Show)

-- | Declaration information
data Declaration = Declaration { declName     :: Text
                               , declType     :: Maybe Text
                               , declKind     :: SymbolKind
                               , declRange    :: Range
                               , declChildren :: [Declaration]
                               }
     deriving (Eq, Generic, Show)

-- | Import information
data Import = Import { importModule    :: Text
                     , importQualified :: Bool
                     , importAs        :: Maybe Text
                     , importList      :: Maybe [Text]
                     }
     deriving (Eq, Generic, Show)

-- | Export information
data Export = Export { exportName :: Text
                     , exportKind :: SymbolKind
                     }
     deriving (Eq, Generic, Show)

-- | Parse error information
data ParseError = ParseError { parseErrorMessage :: Text
                             , parseErrorRange   :: Maybe Range
                             }
     deriving (Eq, Generic, Show)

-- | Symbol information for resolution
data SymbolInfo = SymbolInfo { symName          :: Text
                             , symType          :: Maybe Text
                             , symKind          :: SymbolKind
                             , symLocation      :: Location
                             , symDocumentation :: Maybe Text
                             }
     deriving (Eq, Generic, Show)

-- | Simple parser state (for future use)
data ParserState = ParserState { psInput  :: Text
                               , psLine   :: Int
                               , psColumn :: Int
                               , psOffset :: Int
                               }
     deriving (Eq, Show)

-- | Parse a Haskell source file using a simple regex-based approach
parseModule :: Text -> Either ParseError ParsedModule
parseModule sourceText =
  case runSimpleParser sourceText of
    Left err     -> Left err
    Right result -> Right result

-- | Run simple parser
runSimpleParser :: Text -> Either ParseError ParsedModule
runSimpleParser sourceText = do
  let linesOfCode = T.lines sourceText

  -- Check for basic syntax errors first
  case validateBasicSyntax linesOfCode of
    Just err -> Left err
    Nothing -> do
      let imports = parseImports linesOfCode
      let exports = parseExports linesOfCode
      let declarations = parseDeclarations linesOfCode

      Right <| ParsedModule
        { pmSource = sourceText
        , pmDeclarations = declarations
        , pmImports = imports
        , pmExports = exports
        }

-- | Validate basic syntax and return first error found
validateBasicSyntax :: [Text] -> Maybe ParseError
validateBasicSyntax linesOfCode =
  let numberedLines = zip [0..] linesOfCode
      syntaxChecks = concatMap checkBasicLineSyntax numberedLines
  in case syntaxChecks of
    []      -> Nothing
    (err:_) -> Just err

-- | Check basic syntax issues on a single line
checkBasicLineSyntax :: (Int, Text) -> [ParseError]
checkBasicLineSyntax (lineNum, line) =
  checkSeverelyMalformed lineNum line <> checkInvalidModuleDecl lineNum line

-- | Check for severely malformed syntax
checkSeverelyMalformed :: Int -> Text -> [ParseError]
checkSeverelyMalformed lineNum line =
  let trimmed = T.strip line
  in if not (T.null trimmed) &&
        not (T.isPrefixOf "--" trimmed) &&
        T.any (\c -> c `elem` ("\0\1\2\3\4\5\6\7\8" :: String)) line
     then [ParseError
           "Invalid control characters in source code"
           (Just <| Range (Position (fromIntegral lineNum) 0)
                        (Position (fromIntegral lineNum) (fromIntegral <| T.length line)))]
     else []

-- | Check for invalid module declarations
checkInvalidModuleDecl :: Int -> Text -> [ParseError]
checkInvalidModuleDecl lineNum line =
  let trimmed = T.strip line
  in if T.isPrefixOf "module " trimmed
     then case T.words trimmed of
       ["module"] -> [ParseError
                     "Incomplete module declaration"
                     (Just <| Range (Position (fromIntegral lineNum) 0)
                                  (Position (fromIntegral lineNum) (fromIntegral <| T.length line)))]
       ("module":name:_) ->
         if not (isValidModuleName name)
         then [ParseError
               ("Invalid module name: " <> name)
               (Just <| Range (Position (fromIntegral lineNum) 7)
                            (Position (fromIntegral lineNum) (fromIntegral <| 7 + T.length name)))]
         else []
       _ -> []
     else []

-- | Check if a module name is valid
isValidModuleName :: Text -> Bool
isValidModuleName name =
  not (T.null name) &&
  T.all (\c -> isAlphaNum c || c == '.' || c == '_') name &&
  isAlpha (T.head name)

-- | Parse import declarations
parseImports :: [Text] -> [Import]
parseImports linesOfCode =
  let importLines = filter (T.isPrefixOf "import ") linesOfCode
  in map parseImportLine importLines

-- | Parse a single import line
parseImportLine :: Text -> Import
parseImportLine line =
  let tokens = T.words line
      isQualified = "qualified" `elem` tokens
      moduleName = case dropWhile (/= "import") tokens of
        ("import":"qualified":name:_) -> name
        ("import":name:_)             -> name
        _                             -> "Unknown"
      asName = case dropWhile (/= "as") tokens of
        ("as":name:_) -> Just name
        _             -> Nothing
  in Import
    { importModule = moduleName
    , importQualified = isQualified
    , importAs = asName
    , importList = Nothing
    }

-- | Parse export list from module header
parseExports :: [Text] -> Maybe [Export]
parseExports linesOfCode =
  let moduleLines = filter (T.isPrefixOf "module ") linesOfCode
  in case moduleLines of
    [] -> Nothing
    (line:_) ->
      if T.isInfixOf "(" line && T.isInfixOf ")" line
      then Just [Export "example" SymbolKind_Function] -- Simplified
      else Nothing

-- | Parse top-level declarations
parseDeclarations :: [Text] -> [Declaration]
parseDeclarations linesOfCode =
  let numberedLines = zip [0..] linesOfCode
      functionDecls = concatMap parseFunctionDecl numberedLines
      dataDecls = concatMap parseDataDecl numberedLines
      typeDecls = concatMap parseTypeDecl numberedLines
      classDecls = concatMap parseClassDecl numberedLines
  in functionDecls <> dataDecls <> typeDecls <> classDecls

-- | Parse function declarations
parseFunctionDecl :: (Int, Text) -> [Declaration]
parseFunctionDecl (lineNum, line) =
  let trimmed = T.strip line
  in if isFunctionDeclaration trimmed
     then case T.words trimmed of
       (name:_) ->
         let range = Range (Position (fromIntegral lineNum) 0)
                          (Position (fromIntegral lineNum) (fromIntegral <| T.length line))
         in [Declaration name Nothing SymbolKind_Function range []]
       _ -> []
     else []

-- | Check if line is a function declaration
isFunctionDeclaration :: Text -> Bool
isFunctionDeclaration line =
  let trimmed = T.strip line
  in not (T.null trimmed) &&
     not (T.isPrefixOf "--" trimmed) &&
     not (T.isPrefixOf "import " trimmed) &&
     not (T.isPrefixOf "module " trimmed) &&
     not (T.isPrefixOf "data " trimmed) &&
     not (T.isPrefixOf "type " trimmed) &&
     not (T.isPrefixOf "class " trimmed) &&
     not (T.isPrefixOf "instance " trimmed) &&
     T.isInfixOf "::" trimmed &&
     case T.words trimmed of
       (name:_) -> isValidIdentifier name
       _        -> False

-- | Parse data declarations
parseDataDecl :: (Int, Text) -> [Declaration]
parseDataDecl (lineNum, line) =
  let trimmed = T.strip line
  in if T.isPrefixOf "data " trimmed
     then case T.words trimmed of
       ("data":name:_) ->
         let range = Range (Position (fromIntegral lineNum) 0)
                          (Position (fromIntegral lineNum) (fromIntegral <| T.length line))
         in [Declaration name Nothing SymbolKind_Struct range []]
       _ -> []
     else []

-- | Parse type declarations
parseTypeDecl :: (Int, Text) -> [Declaration]
parseTypeDecl (lineNum, line) =
  let trimmed = T.strip line
  in if T.isPrefixOf "type " trimmed
     then case T.words trimmed of
       ("type":name:_) ->
         let range = Range (Position (fromIntegral lineNum) 0)
                          (Position (fromIntegral lineNum) (fromIntegral <| T.length line))
         in [Declaration name Nothing SymbolKind_Class range []]
       _ -> []
     else []

-- | Parse class declarations
parseClassDecl :: (Int, Text) -> [Declaration]
parseClassDecl (lineNum, line) =
  let trimmed = T.strip line
  in if T.isPrefixOf "class " trimmed
     then case T.words trimmed of
       ("class":name:_) ->
         let range = Range (Position (fromIntegral lineNum) 0)
                          (Position (fromIntegral lineNum) (fromIntegral <| T.length line))
         in [Declaration name Nothing SymbolKind_Class range []]
       _ -> []
     else []

-- | Check if a string is a valid Haskell identifier
isValidIdentifier :: Text -> Bool
isValidIdentifier name =
  not (T.null name) &&
  isAlpha (T.head name) &&
  T.all (\c -> isAlphaNum c || c == '_' || c == '\'') name

-- | Resolve symbol at position
resolveSymbol :: ParsedModule -> Position -> Maybe SymbolInfo
resolveSymbol parsedModule position =
  let declarations = pmDeclarations parsedModule
      matchingDecls = filter (positionInRange position . declRange) declarations
  in case matchingDecls of
    [] -> Nothing
    (decl:_) -> Just <| declarationToSymbolInfo decl (createDummyUri "file:///dummy.hs")

-- | Get all symbols in scope at position
symbolsInScope :: ParsedModule -> Position -> [SymbolInfo]
symbolsInScope parsedModule _position =
  let declarations = pmDeclarations parsedModule
      imports = pmImports parsedModule
      declSymbols = map (\decl -> declarationToSymbolInfo decl (createDummyUri "file:///dummy.hs")) declarations
      importSymbols = concatMap importToSymbolInfos imports
  in declSymbols <> importSymbols

-- | Check if position is within range
positionInRange :: Position -> Range -> Bool
positionInRange pos range =
  let Position line char = pos
      Range (Position startLine startChar) (Position endLine endChar) = range
  in (line > startLine || (line == startLine && char >= startChar)) &&
     (line < endLine || (line == endLine && char <= endChar))

-- | Convert Declaration to SymbolInfo
declarationToSymbolInfo :: Declaration -> Uri -> SymbolInfo
declarationToSymbolInfo decl uri = SymbolInfo
  { symName = declName decl
  , symType = declType decl
  , symKind = declKind decl
  , symLocation = Location uri (declRange decl)
  , symDocumentation = Nothing
  }

-- | Convert Import to SymbolInfos (simplified)
importToSymbolInfos :: Import -> [SymbolInfo]
importToSymbolInfos imp =
  let dummyRange = Range (Position 0 0) (Position 0 (fromIntegral <| T.length <| importModule imp))
      dummyUri = createDummyUri "file:///dummy.hs"
  in [SymbolInfo
      { symName = importModule imp
      , symType = Nothing
      , symKind = SymbolKind_Module
      , symLocation = Location dummyUri dummyRange
      , symDocumentation = Nothing
      }]

-- | Create a dummy URI (for testing purposes)
createDummyUri :: Text -> Uri
createDummyUri uriText =
  -- This is a simplified URI creation for testing
  -- In a real implementation, this would use proper URI parsing
  case T.unpack uriText of
    str -> read ("\"" <> str <> "\"") -- Simple string to Uri conversion

-- | Pretty print a parsed module (for round-trip testing)
printModule :: ParsedModule -> Text
printModule parsedModule =
  let exportsText = case pmExports parsedModule of
        Nothing -> ""
        Just exports -> "(" <> T.intercalate ", " (map exportName exports) <> ")"

      importsText = T.unlines <| map printImport (pmImports parsedModule)

      declsText = T.unlines <| map printDeclaration (pmDeclarations parsedModule)

  in "module Module" <> exportsText <> " where\n\n" <> importsText <> "\n" <> declsText

-- | Print an import declaration
printImport :: Import -> Text
printImport imp =
  let qualText = if importQualified imp then "qualified " else ""
      asText = case importAs imp of
        Nothing    -> ""
        Just alias -> " as " <> alias
  in "import " <> qualText <> importModule imp <> asText

-- | Print a declaration
printDeclaration :: Declaration -> Text
printDeclaration decl =
  case declKind decl of
    SymbolKind_Function -> declName decl <> " = undefined"
    SymbolKind_Class    -> "data " <> declName decl
    _                   -> declName decl
