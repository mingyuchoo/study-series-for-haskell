{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Presentation.Server
  ( loadConfigFromEnv
  , runServer
  ) where

import Configuration.Dotenv (defaultConfig, loadFile)

import Control.Exception (SomeException, catch)

import Data.Text qualified as T
import Data.Text.IO qualified as TIO

import Domain.Ports

import Network.Wai.Handler.Warp

import Presentation.API

import Servant

import System.Environment (lookupEnv)
import System.Exit (die)

loadConfigFromEnv :: IO ChatConfig
loadConfigFromEnv = do
  _ <- loadFile defaultConfig `catch` \(_ :: SomeException) -> pure ()

  apiKey' <- lookupEnv "AZURE_OPENAI_API_KEY"
  endpoint' <- lookupEnv "AZURE_OPENAI_ENDPOINT"
  deployment' <- lookupEnv "AZURE_OPENAI_DEPLOYMENT"
  apiVersion' <- lookupEnv "AZURE_OPENAI_API_VERSION"

  case (apiKey', endpoint', deployment', apiVersion') of
    (Just k, Just e, Just d, Just v) ->
      pure $
        ChatConfig
          { configApiKey = T.pack k
          , configEndpoint = T.pack e
          , configDeployment = T.pack d
          , configApiVersion = T.pack v
          }
    _ -> die "Missing required environment variables"

runServer :: ChatConfig -> IO ()
runServer config = do
  let port = 8000
  TIO.putStrLn $ "Starting server on http://localhost:" <> T.pack (show port)
  TIO.putStrLn "Available endpoints:"
  TIO.putStrLn "  - Web UI: http://localhost:8000/"
  TIO.putStrLn "  - API: http://localhost:8000/api/chat"
  TIO.putStrLn "  - Health: http://localhost:8000/health"
  TIO.putStrLn "  - Swagger UI: http://localhost:8000/swagger-ui"
  TIO.putStrLn "  - OpenAPI JSON: http://localhost:8000/openapi.json"
  run port (serve api $ server config)
