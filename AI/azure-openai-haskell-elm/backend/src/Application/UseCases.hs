{-# LANGUAGE OverloadedStrings #-}

module Application.UseCases
  ( sendChatMessage
  , streamChatMessage
  ) where

import Data.Text (Text)

import Domain.Entities
import Domain.Ports

sendChatMessage :: (ChatService m) => ChatConfig -> [ChatMessage] -> m Text
sendChatMessage = sendMessage

streamChatMessage
  :: (ChatService m) => ChatConfig -> [ChatMessage] -> (Text -> IO ()) -> m ()
streamChatMessage = streamMessage
