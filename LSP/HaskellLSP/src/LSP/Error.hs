{-# LANGUAGE OverloadedStrings #-}

-- | Error handling and recovery for LSP server
module LSP.Error
    ( -- * Error Classification
      ErrorRecovery (..)
    , ErrorSeverity (..)
    , classifyError
    , defaultErrorRecovery
      -- * Error Handling
    , handleLspError
    , recoverFromError
    , withErrorRecovery
      -- * Logging
    , LogContext (..)
    , defaultLogContext
    , logDebug
    , logError
    , logInfo
    , logWarning
    , withLogging
    ) where

import           Control.Concurrent     (threadDelay)
import           Control.Exception      (SomeException, catch, try)
import           Control.Monad.IO.Class (MonadIO, liftIO)

import           Data.Text              (Text)
import qualified Data.Text              as T
import           Data.Time              (defaultTimeLocale, formatTime,
                                         getCurrentTime)

import           Flow                   ((<|))

import           LSP.Types              (ErrorRecovery (..), ErrorSeverity (..),
                                         LogLevel (..), ResponseError,
                                         mkInternalError)

import           System.IO              (Handle, hFlush, hPutStrLn, stderr)

-- | Context for structured logging
data LogContext = LogContext { logHandle :: Handle
                             , logLevel  :: LogLevel
                             , logPrefix :: Text
                             }
     deriving (Show)

-- | Default logging context using stderr
defaultLogContext :: LogContext
defaultLogContext =
  LogContext
    { logHandle = stderr
    , logLevel = Info
    , logPrefix = "[LSP]"
    }

-- | Classify an exception for error recovery
classifyError :: SomeException -> ErrorSeverity
classifyError e
  | "parse" `T.isInfixOf` T.pack (show e) = Recoverable
  | "timeout" `T.isInfixOf` T.pack (show e) = Transient
  | "resource" `T.isInfixOf` T.pack (show e) = Transient
  | "network" `T.isInfixOf` T.pack (show e) = Transient
  | "memory" `T.isInfixOf` T.pack (show e) = Fatal
  | "stack overflow" `T.isInfixOf` T.pack (show e) = Fatal
  | otherwise = Recoverable

-- | Handle LSP-specific errors and convert to ResponseError
handleLspError :: SomeException -> IO ResponseError
handleLspError e = do
  logError defaultLogContext <| "LSP Error: " <> T.pack (show e)
  case classifyError e of
    Fatal -> do
      logError defaultLogContext "Fatal error detected, server should shutdown"
      pure <| mkInternalError "Fatal server error occurred"
    _ -> pure <| mkInternalError <| "Server error: " <> T.pack (show e)

-- | Recover from an error using the specified strategy
recoverFromError :: ErrorRecovery -> SomeException -> IO ()
recoverFromError recovery e = do
  logWarning defaultLogContext <| "Attempting error recovery: " <> T.pack (show e)
  case classifyError e of
    Transient -> do
      logInfo defaultLogContext <|
        "Retrying after " <> T.pack (show (retryDelay recovery)) <> "ms"
      threadDelay (retryDelay recovery * 1000) -- Convert to microseconds
    Recoverable -> do
      logInfo defaultLogContext "Executing fallback action"
      fallbackAction recovery
    Fatal -> do
      logError defaultLogContext "Fatal error - no recovery possible"
      fallbackAction recovery

-- | Execute an action with error recovery
withErrorRecovery :: ErrorRecovery -> IO a -> IO (Either SomeException a)
withErrorRecovery recovery action = do
  result <- try action
  case result of
    Left e -> do
      recoverFromError recovery e
      pure (Left e)
    Right val -> pure (Right val)

-- | Log an error message
logError :: (MonadIO m) => LogContext -> Text -> m ()
logError ctx msg = logWithLevel ctx Error msg

-- | Log a warning message
logWarning :: (MonadIO m) => LogContext -> Text -> m ()
logWarning ctx msg = logWithLevel ctx Warning msg

-- | Log an info message
logInfo :: (MonadIO m) => LogContext -> Text -> m ()
logInfo ctx msg = logWithLevel ctx Info msg

-- | Log a debug message
logDebug :: (MonadIO m) => LogContext -> Text -> m ()
logDebug ctx msg = logWithLevel ctx Debug msg

-- | Log a message with the specified level
logWithLevel :: (MonadIO m) => LogContext -> LogLevel -> Text -> m ()
logWithLevel ctx level msg =
  liftIO <| do
    when (level >= logLevel ctx) <| do
      timestamp <- getCurrentTime
      let timeStr = formatTime defaultTimeLocale "%Y-%m-%d %H:%M:%S" timestamp
          levelStr = case level of
            Debug   -> "DEBUG"
            Info    -> "INFO"
            Warning -> "WARN"
            Error   -> "ERROR"
          fullMsg =
            T.unpack <|
              T.unwords
                [ T.pack timeStr
                , logPrefix ctx
                , T.pack levelStr
                , msg
                ]
      hPutStrLn (logHandle ctx) fullMsg
      hFlush (logHandle ctx)
  where
    when True action = action
    when False _     = pure ()

-- | Execute an action with logging context
withLogging :: LogContext -> IO a -> IO a
withLogging ctx action = do
  logInfo ctx "Starting operation"
  result <-
    action `catch` \e -> do
      logError ctx <| "Operation failed: " <> T.pack (show e)
      handleLspError e >>= \_ -> error (show e) -- Re-throw for now
  logInfo ctx "Operation completed"
  pure result

-- | Default error recovery configuration
defaultErrorRecovery :: ErrorRecovery
defaultErrorRecovery =
  ErrorRecovery
    { maxRetries = 3
    , retryDelay = 1000 -- 1 second
    , fallbackAction = logError defaultLogContext "Fallback action executed"
    }
