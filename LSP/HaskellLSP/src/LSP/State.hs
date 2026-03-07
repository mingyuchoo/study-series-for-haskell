{-# LANGUAGE OverloadedStrings #-}

-- | Document state management for LSP server
-- Provides VFS-based document content retrieval
module LSP.State
    ( getDocumentContent
    ) where

import           Data.Text                   (Text)

import           Language.LSP.Protocol.Types (Uri, toNormalizedUri)
import           Language.LSP.Server         (LspM, getVirtualFile)
import           Language.LSP.VFS            (virtualFileText)

-- | Retrieve document content from the LSP VFS
-- Returns the current content of the document identified by the given URI
getDocumentContent :: Uri -> LspM config (Maybe Text)
getDocumentContent uri = do
  let normalizedUri = toNormalizedUri uri
  maybeVf <- getVirtualFile normalizedUri
  pure <| fmap virtualFileText maybeVf
  where
    (<|) = ($)
