{-# LANGUAGE OverloadedStrings #-}

-- | Hover provider for LSP server
-- Resolves symbol at hover position and formats hover content with type information
module Handlers.Hover
    ( formatHoverContent
    , handleHover
    ) where

import           Analysis.Parser             (SymbolInfo (..), parseModule,
                                              resolveSymbol)

import           Control.Monad.IO.Class      (liftIO)

import           Data.Text                   (Text)
import qualified Data.Text                   as T

import           Flow                        ((<|))

import           LSP.State                   (getDocumentContent)
import           LSP.Types                   (ServerConfig)

import           Language.LSP.Protocol.Types
import           Language.LSP.Server

-- | Handle textDocument/hover request
-- Resolves symbol at hover position and formats hover content with type information
handleHover :: HoverParams -> LspM ServerConfig (Maybe Hover)
handleHover (HoverParams (TextDocumentIdentifier uri) position _workDoneToken) = do
  liftIO <| putStrLn <| "Hover request at position: " <> show position <> " in " <> show uri

  -- TODO: Get document content from server state
  -- For now, we'll simulate getting document content
  -- In a real implementation, this would come from the server state
  maybeContent <- getDocumentContent uri

  case maybeContent of
    Nothing -> do
      liftIO <| putStrLn "Document not found in server state"
      return Nothing
    Just content -> do
      liftIO <|
        putStrLn <|
          "Processing hover for document with " <> show (T.length content) <> " characters"

      -- Parse the document
      case parseModule content of
        Left _parseError -> do
          liftIO <| putStrLn "Failed to parse document for hover"
          return Nothing
        Right parsedModule -> do
          -- Resolve symbol at position
          case resolveSymbol parsedModule position of
            Nothing -> do
              liftIO <| putStrLn "No symbol found at hover position"
              return Nothing
            Just symbolInfo -> do
              liftIO <| putStrLn <| "Found symbol: " <> T.unpack (symName symbolInfo)

              -- Format hover content based on symbol kind
              let hoverContent = formatHoverContent symbolInfo

              case hoverContent of
                Nothing -> return Nothing
                Just hoverText -> do
                  let markupContent = MarkupContent MarkupKind_Markdown hoverText
                      hover =
                        Hover
                          { _contents = InL markupContent -- Use InL for MarkupContent
                          , _range = Nothing -- We could provide the symbol range here
                          }
                  return (Just hover)

-- | Format hover content based on symbol information
-- Returns formatted markdown content for different symbol kinds
formatHoverContent :: SymbolInfo -> Maybe Text
formatHoverContent symbolInfo =
  case symKind symbolInfo of
    SymbolKind_Function ->
      -- Check if it's an operator (starts with non-alphanumeric character)
      let name = symName symbolInfo
       in if T.null name || not (isAlphaNumeric (T.head name))
            then formatOperatorHover symbolInfo
            else formatFunctionHover symbolInfo
    SymbolKind_Class -> formatTypeHover symbolInfo
    SymbolKind_Struct -> formatTypeHover symbolInfo
    SymbolKind_Variable -> formatVariableHover symbolInfo
    SymbolKind_Module -> formatModuleHover symbolInfo
    _ -> formatGenericHover symbolInfo
  where
    isAlphaNumeric c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')

-- | Format hover content for functions
-- Displays function's type signature and documentation
formatFunctionHover :: SymbolInfo -> Maybe Text
formatFunctionHover symbolInfo =
  let name = symName symbolInfo
      typeInfo = case symType symbolInfo of
        Just t -> "```haskell\n" <> name <> " :: " <> t <> "\n```"
        Nothing -> "```haskell\n" <> name <> " :: (type signature not available)\n```"

      documentation = case symDocumentation symbolInfo of
        Just doc -> "\n\n" <> doc
        Nothing  -> ""
   in Just (typeInfo <> documentation)

-- | Format hover content for types (data types, type aliases)
-- Displays type's kind and definition information
formatTypeHover :: SymbolInfo -> Maybe Text
formatTypeHover symbolInfo =
  let name = symName symbolInfo
      kindInfo = case symKind symbolInfo of
        SymbolKind_Class  -> "```haskell\ndata " <> name <> "\n```"
        SymbolKind_Struct -> "```haskell\ndata " <> name <> "\n```"
        _                 -> "```haskell\ntype " <> name <> "\n```"

      documentation = case symDocumentation symbolInfo of
        Just doc -> "\n\n" <> doc
        Nothing  -> ""
   in Just (kindInfo <> documentation)

-- | Format hover content for variables
-- Displays variable's type information
formatVariableHover :: SymbolInfo -> Maybe Text
formatVariableHover symbolInfo =
  let name = symName symbolInfo
      typeInfo = case symType symbolInfo of
        Just t  -> "```haskell\n" <> name <> " :: " <> t <> "\n```"
        Nothing -> "```haskell\n" <> name <> "\n```"

      documentation = case symDocumentation symbolInfo of
        Just doc -> "\n\n" <> doc
        Nothing  -> ""
   in Just (typeInfo <> documentation)

-- | Format hover content for modules
-- Displays module information
formatModuleHover :: SymbolInfo -> Maybe Text
formatModuleHover symbolInfo =
  let name = symName symbolInfo
      moduleInfo = "```haskell\nmodule " <> name <> "\n```"

      documentation = case symDocumentation symbolInfo of
        Just doc -> "\n\n" <> doc
        Nothing  -> ""
   in Just (moduleInfo <> documentation)

-- | Format hover content for operators
-- Displays operator's type and fixity information
formatOperatorHover :: SymbolInfo -> Maybe Text
formatOperatorHover symbolInfo =
  let name = symName symbolInfo
      typeInfo = case symType symbolInfo of
        Just t  -> "```haskell\n(" <> name <> ") :: " <> t <> "\n```"
        Nothing -> "```haskell\n(" <> name <> ")\n```"

      -- TODO: Add fixity information when available
      -- For now, we'll note that fixity information would go here
      fixityInfo = "\n\n*Fixity information not available*"

      documentation = case symDocumentation symbolInfo of
        Just doc -> "\n\n" <> doc
        Nothing  -> ""
   in Just (typeInfo <> fixityInfo <> documentation)

-- | Format generic hover content for unknown symbol kinds
formatGenericHover :: SymbolInfo -> Maybe Text
formatGenericHover symbolInfo =
  let name = symName symbolInfo
      genericInfo = "```haskell\n" <> name <> "\n```"

      documentation = case symDocumentation symbolInfo of
        Just doc -> "\n\n" <> doc
        Nothing  -> ""
   in Just (genericInfo <> documentation)
