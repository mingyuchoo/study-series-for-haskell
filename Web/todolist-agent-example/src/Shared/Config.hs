module Shared.Config (
    AppConfig (..),
    loadConfig,
) where

import Data.Text (Text)
import Data.Text qualified as Text
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

data AppConfig = AppConfig
    { appPort :: Int
    , databaseUrl :: Text
    }
    deriving (Eq, Show)

loadConfig :: IO AppConfig
loadConfig = do
    rawPort <- lookupEnv "APP_PORT"
    rawDatabaseUrl <- lookupEnv "DATABASE_URL"
    port <- case rawPort of
        Nothing -> pure 8080
        Just value -> case readMaybe value of
            Nothing -> fail "APP_PORT must be an integer"
            Just parsed -> pure parsed
    dbUrl <- case rawDatabaseUrl of
        Nothing -> fail "DATABASE_URL is required"
        Just value -> pure (Text.pack value)
    pure AppConfig{appPort = port, databaseUrl = dbUrl}
