{-# LANGUAGE OverloadedStrings #-}

-- | Main LSP server module
-- Implements stdio communication, handler registration, and server capabilities
module LSP.Server
    ( runLspServer
    ) where

import           Control.Monad.IO.Class        (liftIO)

import           Flow                          ((<|))

import           Handlers.Completion           (handleCompletion)
import           Handlers.Definition           (handleDefinition,
                                                handleDocumentSymbol)
import           Handlers.DocumentSync         (handleDidChange, handleDidClose,
                                                handleDidOpen)
import           Handlers.Hover                (handleHover)

import           LSP.Types                     (ServerConfig,
                                                defaultServerConfig)

import           Language.LSP.Protocol.Message
import           Language.LSP.Protocol.Types
import           Language.LSP.Server

import           System.IO                     (BufferMode (..), hSetBuffering,
                                                stdin, stdout)

-- | Main LSP server entry point
-- Implements stdio communication setup and configures server options and handlers
runLspServer :: IO Int
runLspServer = do
  -- Set up stdio for LSP communication
  hSetBuffering stdin NoBuffering
  hSetBuffering stdout NoBuffering

  liftIO <| putStrLn "Starting Haskell LSP Server..."

  -- Run the LSP server with configured handlers
  runServer <|
    ServerDefinition
      { parseConfig = const <| const <| Right defaultServerConfig
      , onConfigChange = \newConfig ->
          liftIO <| putStrLn <| "Configuration changed: " <> show newConfig
      , defaultConfig = defaultServerConfig
      , configSection = "haskellLSP"
      , doInitialize = \env _req -> do
          liftIO <| putStrLn "Server initialized"
          pure <| Right env
      , staticHandlers = \_caps -> lspHandlers
      , interpretHandler = \env -> Iso (\f -> runLspT env f) liftIO
      , options =
          defaultOptions
            { optTextDocumentSync =
                Just
                  TextDocumentSyncOptions
                    { _openClose = Just True
                    , _change = Just TextDocumentSyncKind_Incremental
                    , _willSave = Nothing
                    , _willSaveWaitUntil = Nothing
                    , _save = Just <| InR <| SaveOptions {_includeText = Just False}
                    }
            , optCompletionTriggerCharacters = Just ['.']
            }
      }

-- | LSP request and notification handlers
-- Registers all supported LSP methods with their handler functions
lspHandlers :: Handlers (LspM ServerConfig)
lspHandlers =
  mconcat
    [ -- Document synchronization (notifications)
      notificationHandler SMethod_TextDocumentDidOpen <| \msg -> do
        let TNotificationMessage _ _ params = msg
        handleDidOpen params
    , notificationHandler SMethod_TextDocumentDidChange <| \msg -> do
        let TNotificationMessage _ _ params = msg
        handleDidChange params
    , notificationHandler SMethod_TextDocumentDidClose <| \msg -> do
        let TNotificationMessage _ _ params = msg
        handleDidClose params
    , notificationHandler SMethod_Initialized <| \_msg ->
        liftIO <| putStrLn "Client initialized notification received"
    , -- Hover request
      requestHandler SMethod_TextDocumentHover <| \req responder -> do
        let TRequestMessage _ _ _ params = req
        result <- handleHover params
        responder <| Right <| maybeToNull result
    , -- Completion request
      requestHandler SMethod_TextDocumentCompletion <| \req responder -> do
        let TRequestMessage _ _ _ params = req
        items <- handleCompletion params
        responder <| Right <| InL items
    , -- Definition request
      requestHandler SMethod_TextDocumentDefinition <| \req responder -> do
        let TRequestMessage _ _ _ params = req
        result <- handleDefinition params
        case result of
          Just loc -> responder <| Right <| InL <| Definition <| InL loc
          Nothing  -> responder <| Right <| InR <| InR Null
    , -- Document symbols request
      requestHandler SMethod_TextDocumentDocumentSymbol <| \req responder -> do
        let TRequestMessage _ _ _ params = req
        symbols <- handleDocumentSymbol params
        responder <| Right <| InR (InL symbols)
    ]
