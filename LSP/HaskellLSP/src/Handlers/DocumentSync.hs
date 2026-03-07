{-# LANGUAGE OverloadedStrings #-}

-- | Document synchronization handlers for LSP server
module Handlers.DocumentSync
    ( handleDidChange
    , handleDidClose
    , handleDidOpen
    ) where

import           Analysis.Parser               (parseModule)
import qualified Analysis.Parser

import           Control.Monad.IO.Class        (liftIO)

import           Data.Text                     (Text)

import           Flow                          ((<|))

import           LSP.Diagnostics               (analyzeDiagnostics)
import qualified LSP.Diagnostics               as Diag
import           LSP.State                     (getDocumentContent)
import           LSP.Types                     (ServerConfig)

import           Language.LSP.Protocol.Message
import           Language.LSP.Protocol.Types
import           Language.LSP.Server

-- | Handle textDocument/didOpen notification
-- Triggers initial diagnostics analysis on document open
handleDidOpen :: DidOpenTextDocumentParams -> LspM ServerConfig ()
handleDidOpen (DidOpenTextDocumentParams (TextDocumentItem uri _ _version content)) = do
  liftIO <| putStrLn <| "Document opened: " <> show uri
  analyzeAndPublishDiagnostics uri content

-- | Handle textDocument/didChange notification
-- Retrieves updated content from VFS and triggers diagnostics update
handleDidChange :: DidChangeTextDocumentParams -> LspM ServerConfig ()
handleDidChange (DidChangeTextDocumentParams (VersionedTextDocumentIdentifier uri _version) _changes) = do
  liftIO <| putStrLn <| "Document changed: " <> show uri

  -- VFS automatically applies the changes; retrieve the updated content
  maybeContent <- getDocumentContent uri
  case maybeContent of
    Just content -> analyzeAndPublishDiagnostics uri content
    Nothing      -> liftIO <| putStrLn "Document not found in VFS after change"

-- | Handle textDocument/didClose notification
-- Clears diagnostics for the closed document
handleDidClose :: DidCloseTextDocumentParams -> LspM ServerConfig ()
handleDidClose (DidCloseTextDocumentParams (TextDocumentIdentifier uri)) = do
  liftIO <| putStrLn <| "Document closed: " <> show uri

  -- Clear diagnostics for the closed document
  let clearParams = PublishDiagnosticsParams
        { _uri = uri
        , _version = Nothing
        , _diagnostics = []
        }
  sendNotification SMethod_TextDocumentPublishDiagnostics clearParams

-- | Analyze document content and publish diagnostics to client
analyzeAndPublishDiagnostics :: Uri -> Text -> LspM ServerConfig ()
analyzeAndPublishDiagnostics uri content = do
  liftIO <| putStrLn <| "Analyzing diagnostics for: " <> show uri

  case parseModule content of
    Left _parseError -> do
      let emptyModule = Analysis.Parser.ParsedModule
            { Analysis.Parser.pmSource = content
            , Analysis.Parser.pmDeclarations = []
            , Analysis.Parser.pmImports = []
            , Analysis.Parser.pmExports = Nothing
            }
      Diag.publishDiagnostics uri (analyzeDiagnostics emptyModule)

    Right parsedModule -> do
      let diagnosticInfos = analyzeDiagnostics parsedModule
      Diag.publishDiagnostics uri diagnosticInfos
      liftIO <| putStrLn <| "Published " <> show (length diagnosticInfos) <> " diagnostics"
