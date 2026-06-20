{-# LANGUAGE OverloadedStrings #-}

-- | Completion provider for LSP server
-- Determines completion context and generates completion items
module Handlers.Completion
    ( CompletionContext (..)
    , createCompletionItem
    , determineCompletionContext
    , filterCompletionsByPrefix
    , getCompletions
    , getModuleCompletions
    , handleCompletion
    , normalizeModuleName
    ) where

import           Analysis.Parser             (Import (..), ParsedModule (..),
                                              SymbolInfo (..), parseModule,
                                              symbolsInScope)

import           Control.Lens                ((&), (.~), (^.))
import           Control.Monad.IO.Class      (liftIO)

import           Data.Text                   (Text)
import qualified Data.Text                   as T

import           Flow                        ((<|))

import           LSP.State                   (getDocumentContent)
import           LSP.Types                   (ServerConfig)

import qualified Language.LSP.Protocol.Lens  as L
import           Language.LSP.Protocol.Types hiding (CompletionContext)
import qualified Language.LSP.Protocol.Types as LSP
import           Language.LSP.Server

-- | Completion context information
data CompletionContext = CompletionContext { ccPosition :: Position
                                           , ccPrefix :: Text
                                           , ccModule :: Maybe Text
                                             -- Module qualifier if present
                                           , ccTriggerKind :: CompletionTriggerKind
                                           }
     deriving (Eq, Show)

-- | Handle textDocument/completion request
-- Determines completion context (identifier, module qualifier) and generates completion items
handleCompletion :: CompletionParams -> LspM ServerConfig [CompletionItem]
handleCompletion (CompletionParams textDoc position _workDoneToken _partialResultToken context) = do
  let uri = textDoc ^. L.uri
  liftIO <|
    putStrLn <|
      "Completion request at position: " <> show position <> " in " <> show uri

  -- Get document content from server state
  maybeContent <- getDocumentContent uri

  case maybeContent of
    Nothing -> do
      liftIO <| putStrLn "Document not found in server state"
      return []
    Just content -> do
      liftIO <|
        putStrLn <|
          "Processing completion for document with " <> show (T.length content) <> " characters"

      -- Parse the document
      case parseModule content of
        Left _parseError -> do
          liftIO <| putStrLn "Failed to parse document for completion"
          return []
        Right parsedModule -> do
          -- Determine completion context
          let completionContext = determineCompletionContext content position context
          liftIO <| putStrLn <| "Completion context: " <> show completionContext

          -- Generate completion items
          completionItems <- getCompletions parsedModule completionContext
          liftIO <| putStrLn <| "Generated " <> show (length completionItems) <> " completion items"

          return completionItems

-- | Determine completion context from document content and position
determineCompletionContext
  :: Text -> Position -> Maybe LSP.CompletionContext -> CompletionContext
determineCompletionContext content position maybeContext =
  let lines' = T.lines content
      lineNum = fromIntegral (position ^. L.line)
      charNum = fromIntegral (position ^. L.character)

      currentLine =
        if lineNum < length lines'
          then lines' !! lineNum
          else ""

      -- Extract text before cursor position
      textBeforeCursor = T.take charNum currentLine

      -- Determine trigger kind
      triggerKind = case maybeContext of
        Just ctx -> ctx ^. L.triggerKind
        Nothing  -> CompletionTriggerKind_Invoked

      -- Extract prefix and module qualifier
      (prefix, moduleQualifier) = extractPrefixAndModule textBeforeCursor
   in CompletionContext
        { ccPosition = position
        , ccPrefix = prefix
        , ccModule = moduleQualifier
        , ccTriggerKind = triggerKind
        }

-- | Extract prefix and module qualifier from text before cursor
extractPrefixAndModule :: Text -> (Text, Maybe Text)
extractPrefixAndModule textBeforeCursor =
  let reversed = T.reverse textBeforeCursor
      -- Find the start of the current identifier or qualified name
      (prefixReversed, remaining) = T.span isIdentifierChar reversed
      prefix = T.reverse prefixReversed

      -- Check if there's a module qualifier (look for '.' before the identifier)
      moduleQualifier =
        if T.isPrefixOf "." remaining
          then extractModuleQualifier (T.drop 1 remaining)
          else Nothing
   in (prefix, moduleQualifier)
  where
    isIdentifierChar c =
      (c >= 'a' && c <= 'z')
        || (c >= 'A' && c <= 'Z')
        || (c >= '0' && c <= '9')
        || c == '_'
        || c == '\''

-- | Extract module qualifier from reversed text
extractModuleQualifier :: Text -> Maybe Text
extractModuleQualifier reversedText =
  let (moduleReversed, _) = T.span isModuleChar reversedText
      moduleName = T.reverse moduleReversed
   in if T.null moduleName
        then Nothing
        else Just moduleName
  where
    isModuleChar c =
      (c >= 'a' && c <= 'z')
        || (c >= 'A' && c <= 'Z')
        || (c >= '0' && c <= '9')
        || c == '_'
        || c == '.'

-- | Generate completion items based on parsed module and completion context
getCompletions :: ParsedModule -> CompletionContext -> LspM ServerConfig [CompletionItem]
getCompletions parsedModule completionContext = do
  liftIO <| putStrLn <| "Getting completions for context: " <> show completionContext

  case ccModule completionContext of
    -- Module-qualified completion
    Just moduleName -> do
      liftIO <| putStrLn <| "Getting module-qualified completions for: " <> T.unpack moduleName

      -- Check if this module is imported and get the actual module name
      let actualModuleName = resolveQualifiedModuleName parsedModule moduleName
      liftIO <| putStrLn <| "Resolved module name: " <> T.unpack actualModuleName

      moduleCompletions <- getModuleCompletions actualModuleName
      return <| filterCompletionsByPrefix (ccPrefix completionContext) moduleCompletions

    -- Regular completion (no module qualifier)
    Nothing -> do
      liftIO <| putStrLn "Getting regular completions"
      let symbolsInScopeList = symbolsInScope parsedModule (ccPosition completionContext)
      let completionItems = map symbolInfoToCompletionItem symbolsInScopeList
      return <| filterCompletionsByPrefix (ccPrefix completionContext) completionItems

-- | Get completions for module exports
-- Filters completions by module exports and handles qualified imports
getModuleCompletions :: Text -> LspM ServerConfig [CompletionItem]
getModuleCompletions moduleName = do
  liftIO <| putStrLn <| "Getting completions for module: " <> T.unpack moduleName

  -- Check if this is a qualified module name (e.g., "Map" from "Data.Map as Map")
  -- For now, we'll handle some common qualified names and full module names
  let normalizedModuleName = normalizeModuleName moduleName

  -- Return completions based on well-known modules
  let completions = case normalizedModuleName of
        "Data.List" ->
          [ createCompletionItemWithDoc
              "sort"
              (Just "Ord a => [a] -> [a]")
              CompletionItemKind_Function
              (Just "Sort a list in ascending order")
          , createCompletionItemWithDoc
              "filter"
              (Just "(a -> Bool) -> [a] -> [a]")
              CompletionItemKind_Function
              (Just "Filter elements that satisfy a predicate")
          , createCompletionItemWithDoc
              "map"
              (Just "(a -> b) -> [a] -> [b]")
              CompletionItemKind_Function
              (Just "Apply a function to each element of a list")
          , createCompletionItemWithDoc
              "length"
              (Just "Foldable t => t a -> Int")
              CompletionItemKind_Function
              (Just "Return the length of a structure")
          , createCompletionItemWithDoc
              "reverse"
              (Just "[a] -> [a]")
              CompletionItemKind_Function
              (Just "Reverse a list")
          , createCompletionItemWithDoc
              "head"
              (Just "[a] -> a")
              CompletionItemKind_Function
              (Just "Extract the first element of a list")
          , createCompletionItemWithDoc
              "tail"
              (Just "[a] -> [a]")
              CompletionItemKind_Function
              (Just "Extract all but the first element of a list")
          , createCompletionItemWithDoc
              "null"
              (Just "Foldable t => t a -> Bool")
              CompletionItemKind_Function
              (Just "Test whether a structure is empty")
          ]
        "Data.Map" ->
          [ createCompletionItemWithDoc
              "empty"
              (Just "Map k a")
              CompletionItemKind_Function
              (Just "The empty map")
          , createCompletionItemWithDoc
              "insert"
              (Just "Ord k => k -> a -> Map k a -> Map k a")
              CompletionItemKind_Function
              (Just "Insert a key-value pair into a map")
          , createCompletionItemWithDoc
              "lookup"
              (Just "Ord k => k -> Map k a -> Maybe a")
              CompletionItemKind_Function
              (Just "Look up a value by key")
          , createCompletionItemWithDoc
              "keys"
              (Just "Map k a -> [k]")
              CompletionItemKind_Function
              (Just "Return all keys of the map")
          , createCompletionItemWithDoc
              "values"
              (Just "Map k a -> [a]")
              CompletionItemKind_Function
              (Just "Return all values of the map")
          , createCompletionItemWithDoc
              "fromList"
              (Just "Ord k => [(k, a)] -> Map k a")
              CompletionItemKind_Function
              (Just "Build a map from a list of key-value pairs")
          , createCompletionItemWithDoc
              "toList"
              (Just "Map k a -> [(k, a)]")
              CompletionItemKind_Function
              (Just "Convert a map to a list of key-value pairs")
          ]
        "Control.Monad" ->
          [ createCompletionItemWithDoc
              "when"
              (Just "Applicative f => Bool -> f () -> f ()")
              CompletionItemKind_Function
              (Just "Conditional execution of applicative expressions")
          , createCompletionItemWithDoc
              "unless"
              (Just "Applicative f => Bool -> f () -> f ()")
              CompletionItemKind_Function
              (Just "The reverse of when")
          , createCompletionItemWithDoc
              "mapM"
              (Just "(Traversable t, Monad m) => (a -> m b) -> t a -> m (t b)")
              CompletionItemKind_Function
              (Just "Map each element to a monadic action and collect results")
          , createCompletionItemWithDoc
              "mapM_"
              (Just "(Foldable t, Monad m) => (a -> m b) -> t a -> m ()")
              CompletionItemKind_Function
              (Just "Map each element to a monadic action, ignoring results")
          , createCompletionItemWithDoc
              "forM"
              (Just "(Traversable t, Monad m) => t a -> (a -> m b) -> m (t b)")
              CompletionItemKind_Function
              (Just "mapM with arguments flipped")
          , createCompletionItemWithDoc
              "forM_"
              (Just "(Foldable t, Monad m) => t a -> (a -> m b) -> m ()")
              CompletionItemKind_Function
              (Just "mapM_ with arguments flipped")
          ]
        _ ->
          -- For unknown modules, return empty list
          []

  return completions

-- | Normalize module name to handle qualified imports
-- Maps common qualified names to their full module names
normalizeModuleName :: Text -> Text
normalizeModuleName moduleName =
  case moduleName of
    -- Common qualified import aliases
    "Map"         -> "Data.Map"
    "Set"         -> "Data.Set"
    "List"        -> "Data.List"
    "Maybe"       -> "Data.Maybe"
    "Either"      -> "Data.Either"
    "Text"        -> "Data.Text"
    "ByteString"  -> "Data.ByteString"
    "Vector"      -> "Data.Vector"
    "Monad"       -> "Control.Monad"
    "Applicative" -> "Control.Applicative"
    "Functor"     -> "Data.Functor"
    -- If no alias match, return as-is (could be full module name)
    _             -> moduleName

-- | Resolve qualified module name using import statements from parsed module
-- Handles qualified imports and aliases (e.g., "Map" -> "Data.Map")
resolveQualifiedModuleName :: ParsedModule -> Text -> Text
resolveQualifiedModuleName parsedModule qualifierName =
  let imports = pmImports parsedModule

      -- Look for qualified imports with aliases
      matchingImport = findMatchingImport imports qualifierName
   in case matchingImport of
        Just moduleName -> moduleName
        Nothing         -> normalizeModuleName qualifierName

-- | Find matching import for a qualifier name
findMatchingImport :: [Analysis.Parser.Import] -> Text -> Maybe Text
findMatchingImport imports qualifierName =
  let matchingImports = filter (matchesQualifier qualifierName) imports
   in case matchingImports of
        (imp : _) -> Just (Analysis.Parser.importModule imp)
        []        -> Nothing

-- | Check if an import matches a qualifier name
matchesQualifier :: Text -> Analysis.Parser.Import -> Bool
matchesQualifier qualifierName imp =
  case Analysis.Parser.importAs imp of
    -- Check if the import has an alias that matches
    Just alias -> alias == qualifierName
    -- If no alias, check if it's a qualified import and the qualifier matches the module name
    Nothing ->
      if Analysis.Parser.importQualified imp
        then
          -- For qualified imports without alias, use the last part of module name
          let moduleName = Analysis.Parser.importModule imp
              lastPart = T.takeWhileEnd (/= '.') moduleName
           in lastPart == qualifierName
        else False

-- | Convert SymbolInfo to CompletionItem
-- Includes type signature in completion detail and adds documentation when available
symbolInfoToCompletionItem :: SymbolInfo -> CompletionItem
symbolInfoToCompletionItem symbolInfo =
  let name = symName symbolInfo
      kind = symbolKindToCompletionItemKind (symKind symbolInfo)
      typeSignature = symType symbolInfo
      documentation = symDocumentation symbolInfo

      baseItem = createCompletionItem name typeSignature kind

      -- Add documentation as markdown if available
      docMarkup = case documentation of
        Just doc -> Just <| InR <| MarkupContent MarkupKind_Markdown doc
        Nothing  -> Nothing
   in baseItem & L.documentation .~ docMarkup

-- | Convert SymbolKind to CompletionItemKind
symbolKindToCompletionItemKind :: SymbolKind -> CompletionItemKind
symbolKindToCompletionItemKind symbolKind =
  case symbolKind of
    SymbolKind_Function -> CompletionItemKind_Function
    SymbolKind_Class    -> CompletionItemKind_Class
    SymbolKind_Struct   -> CompletionItemKind_Struct
    SymbolKind_Variable -> CompletionItemKind_Variable
    SymbolKind_Module   -> CompletionItemKind_Module
    _                   -> CompletionItemKind_Text

-- | Create a completion item with documentation
createCompletionItemWithDoc
  :: Text -> Maybe Text -> CompletionItemKind -> Maybe Text -> CompletionItem
createCompletionItemWithDoc name maybeTypeSignature kind maybeDoc =
  let baseItem = createCompletionItem name maybeTypeSignature kind
      docMarkup = case maybeDoc of
        Just doc -> Just <| InR <| MarkupContent MarkupKind_Markdown doc
        Nothing  -> Nothing
   in baseItem & L.documentation .~ docMarkup

-- | Create a completion item with the given name, type signature, and kind
-- Includes type signature in completion detail and adds documentation when available
createCompletionItem :: Text -> Maybe Text -> CompletionItemKind -> CompletionItem
createCompletionItem name maybeTypeSignature kind =
  let
    -- Format the detail with type signature for functions
    detailText = case (kind, maybeTypeSignature) of
      (CompletionItemKind_Function, Just typeSignature) ->
        Just <| name <> " :: " <> typeSignature
      (_, Just typeSignature) -> Just typeSignature
      _ -> Nothing

    -- Set appropriate insert text based on kind
    insertText = case kind of
      CompletionItemKind_Function -> Just name
      _                           -> Just name
   in
    LSP.CompletionItem
      { _label = name
      , _labelDetails = Nothing
      , _kind = Just kind
      , _tags = Nothing
      , _detail = detailText
      , _documentation = Nothing
      , _deprecated = Nothing
      , _preselect = Nothing
      , _sortText = Nothing
      , _filterText = Nothing
      , _insertText = insertText
      , _insertTextFormat = Just InsertTextFormat_PlainText
      , _insertTextMode = Nothing
      , _textEdit = Nothing
      , _textEditText = Nothing
      , _additionalTextEdits = Nothing
      , _commitCharacters = Nothing
      , _command = Nothing
      , _data_ = Nothing
      }

-- | Filter completion items by prefix
filterCompletionsByPrefix :: Text -> [CompletionItem] -> [CompletionItem]
filterCompletionsByPrefix prefix completionItems =
  if T.null prefix
    then completionItems
    else
      filter
        (\item -> T.toLower prefix `T.isPrefixOf` T.toLower (item ^. L.label))
        completionItems
