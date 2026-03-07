{-# LANGUAGE DeriveGeneric      #-}
{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings  #-}

-- | Diagnostics engine for syntax error detection and reporting
module LSP.Diagnostics
    ( -- * Diagnostic Types
      DiagnosticInfo (..)
    , DiagnosticSeverity (..)
      -- * Syntax Error Detection
    , analyzeDiagnostics
    , detectSyntaxErrors
      -- * LSP Conversion
    , publishDiagnostics
    , toLspDiagnostic
      -- * Error Classification
    , classifySyntaxError
    ) where

import           Analysis.Parser               (ParseError (..),
                                                ParsedModule (..), parseModule)

import           Data.Text                     (Text)
import qualified Data.Text                     as T

import           Flow                          ((<|))

import           GHC.Generics                  (Generic)

import           Language.LSP.Protocol.Message (SMethod (SMethod_TextDocumentPublishDiagnostics))
import           Language.LSP.Protocol.Types   (Diagnostic (..),
                                                DiagnosticSeverity (..),
                                                Position (..),
                                                PublishDiagnosticsParams (..),
                                                Range (..), Uri)
import           Language.LSP.Server           (LspM, sendNotification)

-- | Internal diagnostic information
data DiagnosticInfo = DiagnosticInfo { diagRange    :: Range
                                     , diagSeverity :: DiagnosticSeverity
                                     , diagMessage  :: Text
                                     , diagCode     :: Maybe Text
                                     , diagSource   :: Text
                                     }
     deriving (Eq, Generic, Show)

-- | Analyze document and produce diagnostics
analyzeDiagnostics :: ParsedModule -> [DiagnosticInfo]
analyzeDiagnostics parsedModule =
  let sourceText = pmSource parsedModule
  in detectSyntaxErrors sourceText

-- | Detect syntax errors in Haskell source code
detectSyntaxErrors :: Text -> [DiagnosticInfo]
detectSyntaxErrors sourceText =
  case parseModule sourceText of
    Left parseError -> [parseErrorToDiagnostic parseError]
    Right _parsedModule ->
      -- Parsing succeeded; only check for control characters
      let linesOfCode = T.lines sourceText
          numberedLines = zip [0..] linesOfCode
      in concatMap checkInvalidChars numberedLines

-- | Convert ParseError to DiagnosticInfo
parseErrorToDiagnostic :: ParseError -> DiagnosticInfo
parseErrorToDiagnostic parseError =
  let range = case parseErrorRange parseError of
        Just r  -> r
        Nothing -> Range (Position 0 0) (Position 0 1)
  in DiagnosticInfo range DiagnosticSeverity_Error
       (parseErrorMessage parseError) (Just "parse-error") "haskell-lsp"

-- | Check for invalid control characters
checkInvalidChars :: (Int, Text) -> [DiagnosticInfo]
checkInvalidChars (lineNum, line) =
  let hasInvalidChars = T.any isControlChar line
  in if hasInvalidChars
     then [createDiagnostic lineNum line "Invalid control characters found" "invalid-chars"]
     else []
  where
    isControlChar c = c < ' ' && c /= '\t' && c /= '\n' && c /= '\r'

-- | Create a diagnostic for a specific line
createDiagnostic :: Int -> Text -> Text -> Text -> DiagnosticInfo
createDiagnostic lineNum line message code =
  let range = Range
        (Position (fromIntegral lineNum) 0)
        (Position (fromIntegral lineNum) (fromIntegral <| T.length line))
  in DiagnosticInfo range DiagnosticSeverity_Error message (Just code) "haskell-lsp"

-- | Classify syntax error type for better error reporting
classifySyntaxError :: Text -> Text
classifySyntaxError errorMsg
  | "parse error" `T.isInfixOf` T.toLower errorMsg = "parse-error"
  | "unexpected" `T.isInfixOf` T.toLower errorMsg = "unexpected-token"
  | "missing" `T.isInfixOf` T.toLower errorMsg = "missing-token"
  | "unmatched" `T.isInfixOf` T.toLower errorMsg = "unmatched-delimiter"
  | otherwise = "syntax-error"

-- | Convert internal DiagnosticInfo to LSP Diagnostic
toLspDiagnostic :: DiagnosticInfo -> Diagnostic
toLspDiagnostic diagInfo = Diagnostic
  { _range = diagRange diagInfo
  , _severity = Just (diagSeverity diagInfo)
  , _code = Nothing
  , _codeDescription = Nothing
  , _source = Just (diagSource diagInfo)
  , _message = diagMessage diagInfo
  , _tags = Nothing
  , _relatedInformation = Nothing
  , _data_ = Nothing
  }

-- | Publish diagnostics to LSP client
publishDiagnostics :: Uri -> [DiagnosticInfo] -> LspM config ()
publishDiagnostics uri diagnosticInfos = do
  let lspDiagnostics = map toLspDiagnostic diagnosticInfos
      params = PublishDiagnosticsParams
        { _uri = uri
        , _version = Nothing
        , _diagnostics = lspDiagnostics
        }
  sendNotification SMethod_TextDocumentPublishDiagnostics params
