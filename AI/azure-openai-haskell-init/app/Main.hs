{-# LANGUAGE OverloadedStrings #-}

module Main
  ( main
  ) where

import AzureOpenAI

import Configuration.Dotenv (defaultConfig, loadFile)

import Control.Exception (SomeException, catch)
import Control.Monad (foldM)

import Data.IORef
import Data.Text qualified as T
import Data.Text.IO qualified as TIO

import System.Environment (lookupEnv)
import System.Exit (die)
import System.IO (BufferMode (NoBuffering), hFlush, hSetBuffering, stdout)

-- | Load and validate environment variables
loadConfig :: IO Config
loadConfig = do
  -- Try to load .env file (ignore if it doesn't exist)
  _ <- loadFile defaultConfig

  apiKey' <- lookupEnv "AZURE_OPENAI_API_KEY"
  endpoint' <- lookupEnv "AZURE_OPENAI_ENDPOINT"
  deployment' <- lookupEnv "AZURE_OPENAI_DEPLOYMENT"
  apiVersion' <- lookupEnv "AZURE_OPENAI_API_VERSION"

  case (apiKey', endpoint', deployment', apiVersion') of
    (Just k, Just e, Just d, Just v) ->
      pure $
        Config
          { apiKey = T.pack k
          , endpoint = T.pack e
          , deployment = T.pack d
          , apiVersion = T.pack v
          }
    _ -> die "Missing required environment variables. Please check your .env file."

-- | Run multi-turn conversation
runMultiTurnConversation :: Config -> IO ()
runMultiTurnConversation config = do
  TIO.putStrLn "Starting multi-turn conversation...\n"

  -- Initialize conversation history with system message
  let systemMsg = Message System "You are a helpful assistant named Agent37."

  -- Define conversation turns
  let userMessages =
        [ "Hi Agent37, what's your name?"
        , "Can you help me understand what Haskell is?"
        , "What are the main benefits of using it?"
        ]

  -- Process each turn
  _ <- foldM (processTurn config) [systemMsg] userMessages

  TIO.putStrLn "Conversation completed!"

-- | Process a single conversation turn
processTurn :: Config -> [Message] -> T.Text -> IO [Message]
processTurn config history userMsg = do
  -- Add user message to history
  let newHistory = history ++ [Message User userMsg]

  TIO.putStrLn $ "User: " <> userMsg
  TIO.putStr "Assistant: "
  hFlush stdout

  -- Create chat request
  let request =
        ChatRequest
          { messages = newHistory
          , model = deployment config
          , stream = True
          , maxTokens = 4096
          , temperature = 1.0
          , topP = 1.0
          }

  -- Stream response and collect full text
  fullResponse <- collectResponse config request

  TIO.putStrLn "\n"

  -- Add assistant response to history
  pure $ newHistory ++ [Message Assistant fullResponse]

-- | Collect streaming response
collectResponse :: Config -> ChatRequest -> IO T.Text
collectResponse config request = do
  responseRef <- newIORef ""

  streamChatCompletion config request $ \chunk -> do
    TIO.putStr chunk
    hFlush stdout
    modifyIORef responseRef (<> chunk)

  readIORef responseRef

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  config <- loadConfig
  runMultiTurnConversation config
    `catch` \e -> TIO.putStrLn $ "An error occurred: " <> T.pack (show (e :: SomeException))
