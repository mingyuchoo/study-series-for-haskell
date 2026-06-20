{-# LANGUAGE DataKinds     #-}
{-# LANGUAGE TypeOperators #-}

-- | Main application entry point and server setup
module Lib
  ( -- * Application Runner
    appRunner
  ) where

-- -------------------------------------------------------------------
-- Imports
-- -------------------------------------------------------------------

-- Network/Web imports
import Flow ((<|))

import Infrastructure.Repositories.Operations.DatabaseOperations (initializeDatabase)

import Lucid ()

import Network.Wai (Application)
import Network.Wai.Handler.Warp (run)

import Presentation.API.TodoAPI (TodoAPI, todoServer)
import Presentation.Middleware.LoggingMiddleware (loggingMiddleware)
import Presentation.Web.WebAPI (WebAPI, webServer)

import Servant (Proxy (..), Server, serve, type (:<|>) (..))
import Servant.HTML.Lucid ()

-- -------------------------------------------------------------------
-- Application
-- -------------------------------------------------------------------

-- | Create the WAI application by combining all API endpoints
-- with request/response logging middleware
app :: Application
app = loggingMiddleware <| serve appAPI appServer

-- | Run the application server
--
-- This function:
-- 1. Initializes the database (creates tables if they don't exist)
-- 2. Starts the web server on port 8000
appRunner :: IO ()
appRunner = do
  putStrLn "Starting server on port 8000..."
  -- Initialize database (creates tables if they don't exist)
  _ <- initializeDatabase
  -- Start the web server
  run 8000 app

-- -------------------------------------------------------------------
-- API Definitions
-- -------------------------------------------------------------------

-- | Combined API type that includes both REST API and Web interface
--
-- This combines:
-- * TodoAPI - REST API for Todo operations
-- * WebAPI - Web interface with HTML pages
type AppAPI = TodoAPI :<|> WebAPI

-- | API proxy for the combined API
appAPI :: Proxy AppAPI
appAPI = Proxy

-- | Combined server implementation
--
-- This combines the server implementations from both APIs
appServer :: Server AppAPI
appServer = todoServer :<|> webServer
