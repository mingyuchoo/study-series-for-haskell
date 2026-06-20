{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Infrastructure.AzureOpenAI
  ( AzureOpenAIService (..)
  ) where

import Domain.Entities
import Domain.Ports

import Lib qualified as Azure

newtype AzureOpenAIService = AzureOpenAIService ()

instance ChatService IO where
  sendMessage config messages = do
    let azureConfig = toAzureConfig config
    let azureMessages = map toAzureMessage messages
    let request =
          Azure.ChatRequest
            { Azure.messages = azureMessages
            , Azure.model = configDeployment config
            , Azure.stream = False
            , Azure.maxTokens = 4096
            , Azure.temperature = 1.0
            , Azure.topP = 1.0
            }
    Azure.createChatCompletion azureConfig request

  streamMessage config messages callback = do
    let azureConfig = toAzureConfig config
    let azureMessages = map toAzureMessage messages
    let request =
          Azure.ChatRequest
            { Azure.messages = azureMessages
            , Azure.model = configDeployment config
            , Azure.stream = True
            , Azure.maxTokens = 4096
            , Azure.temperature = 1.0
            , Azure.topP = 1.0
            }
    Azure.streamChatCompletion azureConfig request callback

toAzureConfig :: ChatConfig -> Azure.Config
toAzureConfig config =
  Azure.Config
    { Azure.apiKey = configApiKey config
    , Azure.endpoint = configEndpoint config
    , Azure.deployment = configDeployment config
    , Azure.apiVersion = configApiVersion config
    }

toAzureMessage :: ChatMessage -> Azure.Message
toAzureMessage msg =
  Azure.Message
    { Azure.role = toAzureRole (messageRole msg)
    , Azure.content = messageContent msg
    }

toAzureRole :: ChatRole -> Azure.Role
toAzureRole SystemRole    = Azure.System
toAzureRole UserRole      = Azure.User
toAzureRole AssistantRole = Azure.Assistant
