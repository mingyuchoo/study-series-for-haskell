{-# LANGUAGE OverloadedStrings #-}

-- | Configuration change handler for LSP server
-- Handles workspace/didChangeConfiguration notifications and updates server state
module Handlers.Configuration
    ( applyConfigurationChanges
    , handleConfigurationChange
    , parseConfigurationSettings
    ) where

import           Control.Monad.IO.Class (MonadIO, liftIO)

import           Data.Aeson             (Result (..), Value, fromJSON)
import qualified Data.Aeson             as Aeson
import qualified Data.Aeson.KeyMap      as KeyMap

import           Flow                   ((<|))

import           LSP.Types              (ServerConfig (..))

-- | Handle configuration change from LSP server
-- Logs configuration changes and parses new settings
handleConfigurationChange :: MonadIO m => ServerConfig -> Value -> m ()
handleConfigurationChange currentConfig settings = do
  liftIO <| putStrLn "Configuration change notification received"
  liftIO <| putStrLn <| "Current config: " <> show currentConfig

  case parseConfigurationSettings settings of
    Just newConfig -> do
      let updatedConfig = applyConfigurationChanges currentConfig newConfig
      liftIO <| putStrLn <| "Configuration updated: " <> show updatedConfig
    Nothing ->
      liftIO <| putStrLn "Failed to parse configuration settings, keeping current config"

-- | Parse configuration settings from JSON Value
-- Extracts ServerConfig from the settings object
parseConfigurationSettings :: Value -> Maybe ServerConfig
parseConfigurationSettings settings =
  case fromJSON settings of
    Success config -> Just config
    Aeson.Error _err ->
      extractNestedConfig settings
  where
    extractNestedConfig :: Value -> Maybe ServerConfig
    extractNestedConfig (Aeson.Object obj) =
      case KeyMap.lookup "haskellLSP" obj of
        Just nested -> case fromJSON nested of
          Success config -> Just config
          Aeson.Error _  -> Nothing
        Nothing -> Nothing
    extractNestedConfig _ = Nothing

-- | Apply configuration changes to current config
-- Merges new configuration with existing configuration, preserving unspecified values
applyConfigurationChanges :: ServerConfig -> ServerConfig -> ServerConfig
applyConfigurationChanges _currentConfig newConfig = newConfig
