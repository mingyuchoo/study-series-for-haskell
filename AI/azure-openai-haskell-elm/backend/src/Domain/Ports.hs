{-# LANGUAGE OverloadedStrings #-}

module Domain.Ports
  ( ChatConfig (..)
  , ChatService (..)
  ) where

import Data.Text (Text)

import Domain.Entities

data ChatConfig = ChatConfig
  { configApiKey       :: Text
  , configEndpoint     :: Text
  , configDeployment   :: Text
  , configApiVersion   :: Text
  , configSystemPrompt :: Text
  }
  deriving (Show)

class (Monad m) => ChatService m where
  sendMessage :: ChatConfig -> [ChatMessage] -> m Text
  streamMessage :: ChatConfig -> [ChatMessage] -> (Text -> IO ()) -> m ()
