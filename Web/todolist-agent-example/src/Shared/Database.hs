{-# LANGUAGE OverloadedStrings #-}

module Shared.Database (
    DatabaseConfig (..),
    connectDatabase,
) where

import Data.ByteString (ByteString)
import Data.Text (Text)
import Data.Text.Encoding qualified as Text
import Database.PostgreSQL.Simple (Connection, connectPostgreSQL)

newtype DatabaseConfig = DatabaseConfig {databaseConnectionString :: Text}
    deriving (Eq, Show)

connectDatabase :: DatabaseConfig -> IO Connection
connectDatabase (DatabaseConfig value) = connectPostgreSQL (toBytes value)
  where
    toBytes :: Text -> ByteString
    toBytes = Text.encodeUtf8
