{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Lib
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
import Data.Maybe (catMaybes)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding qualified as TE

import Flow ((<|), (|>))

import GHC.Generics

import Network.HTTP.Client
import Network.HTTP.Client.TLS
import Network.HTTP.Types.Header
import Network.HTTP.Types.Status

-- | Azure OpenAI configuration
data Config = Config
  { apiKey :: Text
  , endpoint :: Text
  , deployment :: Text
  , apiVersion :: Text
  }
  deriving (Show)

-- | Message role
data Role = System | User | Assistant
  deriving (Eq, Generic, Show)

instance ToJSON Role where
  toJSON System = String "system"
  toJSON User = String "user"
  toJSON Assistant = String "assistant"

instance FromJSON Role where
  parseJSON =
    withText
      "Role"
      ( \t -> case t of
          "system" -> pure System
          "user" -> pure User
          "assistant" -> pure Assistant
          _ -> fail "Invalid role"
      )

-- | Chat message
data Message = Message
  { role :: Role
  , content :: Text
  }
  deriving (Generic, Show)

instance ToJSON Message where
  toJSON (Message r c) = object ["role" .= r, "content" .= c]

instance FromJSON Message

-- | Chat completion request
data ChatRequest = ChatRequest
  { messages :: [Message]
  , model :: Text
  , stream :: Bool
  , maxTokens :: Maybe Int
  , maxCompletionTokens :: Maybe Int
  , temperature :: Double
  , topP :: Double
  }
  deriving (Generic, Show)

instance ToJSON ChatRequest where
  toJSON req =
    object <|
      catMaybes
        [ Just ("messages" .= messages req)
        , Just ("model" .= model req)
        , Just ("stream" .= stream req)
        , ("max_tokens" .=) <$> maxTokens req
        , ("max_completion_tokens" .=) <$> maxCompletionTokens req
        , Just ("temperature" .= temperature req)
        , Just ("top_p" .= topP req)
        ]

-- | Delta for streaming responses
data Delta = Delta
  { deltaContent :: Maybe Text
  }
  deriving (Generic, Show)

instance FromJSON Delta where
  parseJSON =
    withObject
      "Delta"
      ( \v ->
          Delta <$> v .:? "content"
      )

-- | Choice in response
data Choice = Choice
  { delta :: Maybe Delta
  , message :: Maybe Message
  }
  deriving (Generic, Show)

instance FromJSON Choice where
  parseJSON =
    withObject
      "Choice"
      ( \v ->
          Choice <$> v .:? "delta" <*> v .:? "message"
      )

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
  let cleanEndpoint = T.dropWhileEnd (== '/') (endpoint config)
  let url =
        ( cleanEndpoint
            <> "/openai/deployments/"
            <> deployment config
            <> "/chat/completions?api-version="
            <> apiVersion config
        )
          |> T.unpack

  initialRequest <- parseRequest url
  let request =
        initialRequest
          { method = "POST"
          , requestHeaders =
              [ (hContentType, "application/json")
              , ("api-key", apiKey config |> TE.encodeUtf8)
              ]
          , requestBody = req |> encode |> RequestBodyLBS
          }

  response <- httpLbs request manager

  let status = responseStatus response
  if statusCode status /= 200
    then do
      let bodyText = TE.decodeUtf8 (BL.toStrict (responseBody response))
      ("API request failed: " <> show status <> " - " <> T.unpack bodyText)
        |> userError
        |> throwIO
    else case decode (responseBody response) of
      Nothing -> do
        let bodyText = TE.decodeUtf8 (BL.toStrict (responseBody response))
        ("Failed to parse response: " <> T.unpack bodyText) |> userError |> throwIO
      Just chatResp -> case choices chatResp of
        (Choice _ (Just msg) : _) -> content msg |> pure
        _ -> "No message in response" |> userError |> throwIO

-- | Stream chat completion
streamChatCompletion :: Config -> ChatRequest -> (Text -> IO ()) -> IO ()
streamChatCompletion config req callback = do
  manager <- newManager tlsManagerSettings
  let cleanEndpoint = T.dropWhileEnd (== '/') (endpoint config)
  let url =
        ( cleanEndpoint
            <> "/openai/deployments/"
            <> deployment config
            <> "/chat/completions?api-version="
            <> apiVersion config
        )
          |> T.unpack

  initialRequest <- parseRequest url
  let request =
        initialRequest
          { method = "POST"
          , requestHeaders =
              [ (hContentType, "application/json")
              , ("api-key", apiKey config |> TE.encodeUtf8)
              ]
          , requestBody = RequestBodyLBS <| encode req {stream = True}
          }

  withResponse request manager <|
    ( \response -> do
        let status = responseStatus response
        if statusCode status /= 200
          then do
            bodyChunk <- brRead (responseBody response)
            let bodyText = TE.decodeUtf8 bodyChunk
            ("API streaming request failed: " <> show status <> " - " <> T.unpack bodyText)
              |> userError
              |> throwIO
          else processStream response (responseBody response)
    )
  where
    processStream response body = do
      chunk <- brRead body
      processChunk response chunk body

    processChunk response chunk body
      | BS.null chunk = pure ()
      | otherwise = do
          let linesList = BS.split 10 chunk -- Split by newline
          mapM_ processLine linesList
          processStream response body

    processLine line
      | BS.null line = pure ()
      | BS.isPrefixOf "data: " line = processDataLine line
      | otherwise = pure ()

    processDataLine line = do
      let jsonData = BS.drop 6 line
      processJsonData jsonData

    processJsonData jsonData
      | jsonData == "[DONE]" = pure ()
      | otherwise = case decode (BL.fromStrict jsonData) of
          Just chatResp -> processChoices (choices chatResp)
          Nothing -> pure ()

    processChoices [] = pure ()
    processChoices (Choice (Just d) _ : _) = case deltaContent d of
      Just txt -> callback txt
      Nothing -> pure ()
    processChoices (_ : rest) = processChoices rest
