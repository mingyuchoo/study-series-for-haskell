{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators     #-}

module Presentation.API
  ( API
  , ChatRequest (..)
  , ChatResponse (..)
  , HealthResponse (..)
  , api
  , server
  ) where

import Control.Lens ((&), (.~), (?~))
import Control.Monad.IO.Class (liftIO)

import Data.Aeson
import Data.Swagger
import Data.Text (Text)

import Domain.Entities
import Domain.Ports

import Flow ((<|), (|>))

import GHC.Generics

import Infrastructure.AzureOpenAI ()

import Servant
import Servant.Swagger
import Servant.Swagger.UI

-- API Types
data ChatRequest = ChatRequest
  { chatMessages :: [ChatMessageDTO]
  }
  deriving (Generic, Show)

data ChatMessageDTO = ChatMessageDTO
  { msgRole    :: Text
  , msgContent :: Text
  }
  deriving (Generic, Show)

data ChatResponse = ChatResponse
  { response :: Text
  }
  deriving (Generic, Show)

data HealthResponse = HealthResponse
  { status :: Text
  }
  deriving (Generic, Show)

instance ToJSON ChatRequest
instance FromJSON ChatRequest
instance ToJSON ChatMessageDTO
instance FromJSON ChatMessageDTO
instance ToJSON ChatResponse
instance ToJSON HealthResponse

instance ToSchema ChatRequest
instance ToSchema ChatMessageDTO
instance ToSchema ChatResponse
instance ToSchema HealthResponse

-- API Definition
type ChatAPI =
  "api" :> "chat" :> ReqBody '[JSON] ChatRequest :> Post '[JSON] ChatResponse
    :<|> "health" :> Get '[JSON] HealthResponse

type API =
  ChatAPI
    :<|> SwaggerSchemaUI "swagger-ui" "openapi.json"
    :<|> Raw

api :: Proxy API
api = Proxy

chatAPI :: Proxy ChatAPI
chatAPI = Proxy

-- Server Implementation
server :: ChatConfig -> Server API
server config =
  (chatHandler :<|> healthHandler)
    :<|> swaggerSchemaUIServer swaggerDoc
    :<|> serveDirectoryFileServer "static"
  where
    chatHandler :: ChatRequest -> Handler ChatResponse
    chatHandler req = do
      let messages = map fromDTO (chatMessages req)
      result <- liftIO <| sendMessage config messages
      result |> ChatResponse |> pure

    healthHandler :: Handler HealthResponse
    healthHandler = "ok" |> HealthResponse |> pure

-- Helper Functions
fromDTO :: ChatMessageDTO -> ChatMessage
fromDTO dto =
  ChatMessage
    { messageRole = parseRole (msgRole dto)
    , messageContent = msgContent dto
    }

parseRole :: Text -> ChatRole
parseRole "system"    = SystemRole
parseRole "user"      = UserRole
parseRole "assistant" = AssistantRole
parseRole _           = UserRole

-- Swagger Documentation
swaggerDoc :: Swagger
swaggerDoc =
  toSwagger chatAPI
    & info . title .~ "Azure OpenAI Chat API"
    & info . version .~ "1.0"
    & info . description ?~ "REST API for Azure OpenAI chat service"
