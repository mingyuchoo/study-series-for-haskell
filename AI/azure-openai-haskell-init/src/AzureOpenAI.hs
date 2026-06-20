{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}

module AzureOpenAI
  ( ChatRequest (..)
  , ChatResponse (..)
  , Choice (..)
  , Config (..)
  , Delta (..)
  , Message (..)
  , Role (..)
  , createChatCompletion
  , streamChatCompletion
  ) where

import Control.Exception (throwIO)

import Data.Aeson
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as BL
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding qualified as TE

import GHC.Generics

import Network.HTTP.Client
import Network.HTTP.Client.TLS
import Network.HTTP.Types.Header
import Network.HTTP.Types.Status

-- | Azure OpenAI configuration
data Config = Config
  { apiKey     :: Text
  , endpoint   :: Text
  , deployment :: Text
  , apiVersion :: Text
  }
  deriving (Show)

-- | Message role
data Role = System | User | Assistant
  deriving (Eq, Generic, Show)

instance ToJSON Role where
  toJSON System    = String "system"
  toJSON User      = String "user"
  toJSON Assistant = String "assistant"

instance FromJSON Role where
  parseJSON = withText "Role" $ \t -> case t of
    "system"    -> pure System
    "user"      -> pure User
    "assistant" -> pure Assistant
    _           -> fail "Invalid role"

-- | Chat message
data Message = Message
  { role    :: Role
  , content :: Text
  }
  deriving (Generic, Show)

instance ToJSON Message where
  toJSON (Message r c) = object ["role" .= r, "content" .= c]

instance FromJSON Message

-- | Chat completion request
data ChatRequest = ChatRequest
  { messages    :: [Message]
  , model       :: Text
  , stream      :: Bool
  , maxTokens   :: Int
  , temperature :: Double
  , topP        :: Double
  }
  deriving (Generic, Show)

instance ToJSON ChatRequest where
  toJSON (ChatRequest msgs mdl strm maxTok temp tp) =
    object
      [ "messages" .= msgs
      , "model" .= mdl
      , "stream" .= strm
      , "max_tokens" .= maxTok
      , "temperature" .= temp
      , "top_p" .= tp
      ]

-- | Delta for streaming responses
data Delta = Delta
  { deltaContent :: Maybe Text
  }
  deriving (Generic, Show)

instance FromJSON Delta where
  parseJSON = withObject "Delta" $ \v ->
    Delta <$> v .:? "content"

-- | Choice in response
data Choice = Choice
  { delta   :: Maybe Delta
  , message :: Maybe Message
  }
  deriving (Generic, Show)

instance FromJSON Choice where
  parseJSON = withObject "Choice" $ \v ->
    Choice <$> v .:? "delta" <*> v .:? "message"

-- | Chat completion response
data ChatResponse = ChatResponse
  { choices :: [Choice]
  }
  deriving (Generic, Show)

instance FromJSON ChatResponse

-- | Create chat completion (non-streaming)
createChatCompletion :: Config -> ChatRequest -> IO Text
createChatCompletion config req = do
  manager <- newManager tlsManagerSettings
  let url =
        T.unpack $
          endpoint config
            <> "/openai/deployments/"
            <> deployment config
            <> "/chat/completions?api-version="
            <> apiVersion config

  initialRequest <- parseRequest url
  let request =
        initialRequest
          { method = "POST"
          , requestHeaders =
              [ (hContentType, "application/json")
              , ("api-key", TE.encodeUtf8 $ apiKey config)
              ]
          , requestBody = RequestBodyLBS $ encode req
          }

  response <- httpLbs request manager

  if statusCode (responseStatus response) /= 200
    then throwIO $ userError $ "API request failed: " ++ show (responseStatus response)
    else case decode (responseBody response) of
      Nothing -> throwIO $ userError "Failed to parse response"
      Just chatResp -> case choices chatResp of
        (Choice _ (Just msg) : _) -> pure $ content msg
        _                         -> throwIO $ userError "No message in response"

-- | Stream chat completion
streamChatCompletion :: Config -> ChatRequest -> (Text -> IO ()) -> IO ()
streamChatCompletion config req callback = do
  manager <- newManager tlsManagerSettings
  let url =
        T.unpack $
          endpoint config
            <> "/openai/deployments/"
            <> deployment config
            <> "/chat/completions?api-version="
            <> apiVersion config

  initialRequest <- parseRequest url
  let request =
        initialRequest
          { method = "POST"
          , requestHeaders =
              [ (hContentType, "application/json")
              , ("api-key", TE.encodeUtf8 $ apiKey config)
              ]
          , requestBody = RequestBodyLBS $ encode req {stream = True}
          }

  withResponse request manager $ \response -> do
    if statusCode (responseStatus response) /= 200
      then throwIO $ userError $ "API request failed: " ++ show (responseStatus response)
      else processStream (responseBody response)
  where
    processStream body = do
      chunk <- brRead body
      if BS.null chunk
        then pure ()
        else do
          processChunk chunk
          processStream body

    processChunk chunk = do
      let linesList = BS.split 10 chunk -- Split by newline
      mapM_ processLine linesList

    processLine line
      | BS.null line = pure ()
      | BS.isPrefixOf "data: " line = do
          let jsonData = BS.drop 6 line
          if jsonData == "[DONE]"
            then pure ()
            else case decode (BL.fromStrict jsonData) of
              Just chatResp -> case choices chatResp of
                (Choice (Just d) _ : _) -> case deltaContent d of
                  Just txt -> callback txt
                  Nothing  -> pure ()
                _ -> pure ()
              Nothing -> pure ()
      | otherwise = pure ()
