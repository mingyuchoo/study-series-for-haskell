{-# LANGUAGE DeriveGeneric #-}

module Domain.Entities
  ( ChatMessage (..)
  , ChatRole (..)
  , ChatSession (..)
  , SessionId
  ) where

import Data.Text (Text)
import Data.UUID (UUID)

import GHC.Generics

type SessionId = UUID

data ChatRole = SystemRole | UserRole | AssistantRole
  deriving (Eq, Generic, Show)

data ChatMessage = ChatMessage
  { messageRole    :: ChatRole
  , messageContent :: Text
  }
  deriving (Generic, Show)

data ChatSession = ChatSession
  { sessionId       :: SessionId
  , sessionMessages :: [ChatMessage]
  }
  deriving (Generic, Show)
