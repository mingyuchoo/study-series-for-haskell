{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric  #-}

-- | Core data types for the LSP server
module LSP.Types
    ( -- * Core Types
      LspMessage (..)
    , Method
    , RequestId
    , ResponseError (..)
      -- * Error Handling
    , ErrorRecovery (..)
    , ErrorSeverity (..)
    , LspErrorCode (..)
    , intToLspErrorCode
    , lspErrorCodeToInt
      -- * Error Builders
    , mkInternalError
    , mkInvalidParams
    , mkInvalidRequest
    , mkMethodNotFound
    , mkParseError
    , mkRequestCancelled
    , mkServerNotInitialized
      -- * Configuration
    , LogLevel (..)
    , ServerConfig (..)
    , defaultServerConfig
      -- * Protocol Helpers
    , decodeLspMessage
    , encodeLspMessage
    , extractJsonContent
    , parseContentLength
    , parseJsonRpcMessage
    ) where

import           Data.Aeson                 (FromJSON, ToJSON, Value, decode,
                                             encode)
import           Data.ByteString.Lazy       (ByteString)
import qualified Data.ByteString.Lazy       as LBS
import qualified Data.ByteString.Lazy.Char8 as L8
import           Data.List                  (isPrefixOf)
import           Data.Text                  (Text)

import           Flow                       ((<|))

import           GHC.Generics               (Generic)

-- | Request ID for JSON-RPC messages
type RequestId = Value

-- | Method name for JSON-RPC messages
type Method = Text

-- | JSON-RPC error response
data ResponseError = ResponseError { errorCode    :: Int
                                   , errorMessage :: Text
                                   , errorData    :: Maybe Value
                                   }
     deriving (Eq, FromJSON, Generic, Show, ToJSON)

-- | Standard JSON-RPC error codes
data LspErrorCode -- | -32700: Invalid JSON was received by the server
                  = ParseError
                  -- | -32600: The JSON sent is not a valid Request object
                  | InvalidRequest
                  -- | -32601: The method does not exist / is not available
                  | MethodNotFound
                  -- | -32602: Invalid method parameter(s)
                  | InvalidParams
                  -- | -32603: Internal JSON-RPC error
                  | InternalError
                  -- | -32002: Server has not been initialized
                  | ServerNotInitialized
                  -- | -32001: Unknown error code
                  | UnknownErrorCode
                  -- | -32800: Request was cancelled
                  | RequestCancelled
                  -- | -32801: Content was modified
                  | ContentModified
     deriving (Eq, Generic, Show)

-- | Convert LspErrorCode to integer
lspErrorCodeToInt :: LspErrorCode -> Int
lspErrorCodeToInt ParseError           = -32700
lspErrorCodeToInt InvalidRequest       = -32600
lspErrorCodeToInt MethodNotFound       = -32601
lspErrorCodeToInt InvalidParams        = -32602
lspErrorCodeToInt InternalError        = -32603
lspErrorCodeToInt ServerNotInitialized = -32002
lspErrorCodeToInt UnknownErrorCode     = -32001
lspErrorCodeToInt RequestCancelled     = -32800
lspErrorCodeToInt ContentModified      = -32801

-- | Convert integer to LspErrorCode
intToLspErrorCode :: Int -> LspErrorCode
intToLspErrorCode (-32700) = ParseError
intToLspErrorCode (-32600) = InvalidRequest
intToLspErrorCode (-32601) = MethodNotFound
intToLspErrorCode (-32602) = InvalidParams
intToLspErrorCode (-32603) = InternalError
intToLspErrorCode (-32002) = ServerNotInitialized
intToLspErrorCode (-32001) = UnknownErrorCode
intToLspErrorCode (-32800) = RequestCancelled
intToLspErrorCode (-32801) = ContentModified
intToLspErrorCode _        = UnknownErrorCode

-- | Error response builders
mkParseError :: Text -> ResponseError
mkParseError msg =
  ResponseError
    { errorCode = lspErrorCodeToInt ParseError
    , errorMessage = msg
    , errorData = Nothing
    }

mkInvalidRequest :: Text -> ResponseError
mkInvalidRequest msg =
  ResponseError
    { errorCode = lspErrorCodeToInt InvalidRequest
    , errorMessage = msg
    , errorData = Nothing
    }

mkMethodNotFound :: Text -> ResponseError
mkMethodNotFound method =
  ResponseError
    { errorCode = lspErrorCodeToInt MethodNotFound
    , errorMessage = "Method not found: " <> method
    , errorData = Nothing
    }

mkInvalidParams :: Text -> ResponseError
mkInvalidParams msg =
  ResponseError
    { errorCode = lspErrorCodeToInt InvalidParams
    , errorMessage = msg
    , errorData = Nothing
    }

mkInternalError :: Text -> ResponseError
mkInternalError msg =
  ResponseError
    { errorCode = lspErrorCodeToInt InternalError
    , errorMessage = msg
    , errorData = Nothing
    }

mkServerNotInitialized :: ResponseError
mkServerNotInitialized =
  ResponseError
    { errorCode = lspErrorCodeToInt ServerNotInitialized
    , errorMessage = "Server not initialized"
    , errorData = Nothing
    }

mkRequestCancelled :: RequestId -> ResponseError
mkRequestCancelled _ =
  ResponseError
    { errorCode = lspErrorCodeToInt RequestCancelled
    , errorMessage = "Request was cancelled"
    , errorData = Nothing
    }

-- | LSP message wrapper for JSON-RPC communication
data LspMessage = RequestMessage RequestId Method Value
                | ResponseMessage RequestId (Either ResponseError Value)
                | NotificationMessage Method Value
     deriving (Eq, FromJSON, Generic, Show, ToJSON)

-- | Log levels for server configuration
data LogLevel = Debug | Info | Warning | Error
     deriving (Eq, FromJSON, Generic, Ord, Show, ToJSON)

-- | Server configuration settings
data ServerConfig = ServerConfig { configLogLevel   :: LogLevel
                                 , configLogFile    :: Maybe FilePath
                                 , configMaxWorkers :: Int
                                 }
     deriving (Eq, FromJSON, Generic, Show, ToJSON)

-- | Default server configuration
defaultServerConfig :: ServerConfig
defaultServerConfig =
  ServerConfig
    { configLogLevel = Info
    , configLogFile = Nothing
    , configMaxWorkers = 4
    }

-- | Error classification for recovery strategies
data ErrorSeverity -- | Error that can be handled and processing can continue
                   = Recoverable
                   -- | Error that requires server shutdown
                   | Fatal
                   -- | Temporary error that may succeed on retry
                   | Transient
     deriving (Eq, Generic, Show)

-- | Error recovery configuration
data ErrorRecovery = ErrorRecovery { maxRetries     :: Int
                                   , retryDelay     :: Int
                                     -- ^ milliseconds
                                   , fallbackAction :: IO ()
                                   }

-- | JSON-RPC Protocol Helpers

-- | Encode an LSP message to JSON-RPC format with Content-Length header
encodeLspMessage :: LspMessage -> ByteString
encodeLspMessage msg =
  let jsonBytes = encode msg
      contentLength = LBS.length jsonBytes
      header = L8.pack <| "Content-Length: " <> show contentLength <> "\r\n\r\n"
   in header <> jsonBytes

-- | Decode a JSON-RPC message from ByteString
decodeLspMessage :: ByteString -> Maybe LspMessage
decodeLspMessage = decode

-- | Parse Content-Length header from incoming data
parseContentLength :: ByteString -> Maybe Int
parseContentLength input =
  case L8.lines input of
    [] -> Nothing
    (firstLine : _) ->
      let headerStr = L8.unpack firstLine
          prefix = "Content-Length: "
       in if prefix `isPrefixOf` headerStr
            then case reads (drop (length prefix) headerStr) of
              [(len, rest)] | all (`elem` (" \r\n" :: String)) rest -> Just len
              _                                                     -> Nothing
            else Nothing

-- | Extract JSON content after Content-Length header
extractJsonContent :: ByteString -> Maybe ByteString
extractJsonContent input =
  let inputStr = L8.unpack input
      separator = "\r\n\r\n"
   in case splitOn separator inputStr of
        (_ : rest : _) -> Just (L8.pack rest)
        _              -> Nothing
  where
    splitOn :: String -> String -> [String]
    splitOn _ [] = [""]
    splitOn delim str =
      let (before, remainder) = breakOn delim str
       in before : case remainder of
            [] -> []
            x ->
              if delim `isPrefixOf` x
                then splitOn delim (drop (length delim) x)
                else [x]

    breakOn :: String -> String -> (String, String)
    breakOn _ [] = ([], [])
    breakOn delim str@(c : cs)
      | delim `isPrefixOf` str = ([], str)
      | otherwise =
          let (before, after) = breakOn delim cs
           in (c : before, after)

-- | Parse a complete JSON-RPC message with Content-Length header
parseJsonRpcMessage :: ByteString -> Maybe LspMessage
parseJsonRpcMessage input = do
  contentLength <- parseContentLength input
  jsonContent <- extractJsonContent input
  if LBS.length jsonContent >= fromIntegral contentLength
    then decodeLspMessage (LBS.take (fromIntegral contentLength) jsonContent)
    else Nothing
