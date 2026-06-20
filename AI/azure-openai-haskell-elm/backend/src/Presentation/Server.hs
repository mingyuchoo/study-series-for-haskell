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

import Flow ((|>))

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
  systemPrompt' <- lookupEnv "SYSTEM_PROMPT"

  let defaultPrompt =
        "당신은 친절하고 전문적인 여행 가이드입니다. \
        \사용자의 여행 계획을 돕고, 목적지에 대한 유용한 정보를 제공하며, \
        \현지 문화, 맛집, 관광 명소, 교통 정보 등을 상세히 안내합니다. \
        \항상 안전과 예산을 고려한 조언을 제공하고, \
        \사용자의 선호도와 여행 스타일에 맞춘 맞춤형 추천을 합니다."

  case (apiKey', endpoint', deployment', apiVersion') of
    (Just k, Just e, Just d, Just v) ->
      ChatConfig
        { configApiKey = T.pack k
        , configEndpoint = T.pack e
        , configDeployment = T.pack d
        , configApiVersion = T.pack v
        , configSystemPrompt = maybe defaultPrompt T.pack systemPrompt'
        }
        |> pure
    _ -> die "Missing required environment variables"

runServer :: ChatConfig -> IO ()
runServer config = do
  let port = 8000
  ("Starting server on http://localhost:" <> T.pack (show port)) |> TIO.putStrLn
  TIO.putStrLn "Available endpoints:"
  TIO.putStrLn "  - Web UI: http://localhost:8000/"
  TIO.putStrLn "  - API: http://localhost:8000/api/chat"
  TIO.putStrLn "  - Health: http://localhost:8000/health"
  TIO.putStrLn "  - Swagger UI: http://localhost:8000/swagger-ui"
  TIO.putStrLn "  - OpenAPI JSON: http://localhost:8000/openapi.json"
  run port (server config |> serve api)
