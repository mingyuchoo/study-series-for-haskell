{-# LANGUAGE DataKinds     #-}
{-# LANGUAGE TypeOperators #-}

-- | Web interface API for Todo application
module Presentation.Web.WebAPI
  ( -- * API Type
    WebAPI
    -- * Server Implementation
  , webServer
  ) where

-- -------------------------------------------------------------------
-- Imports
-- -------------------------------------------------------------------

import Control.Monad.IO.Class (liftIO)

import Domain.Repositories.TodoRepository (getAllTodos)

import Flow ((<|))

import Infrastructure.Repositories.SQLiteTodoRepository (SQLiteRepo (..))

import Lucid (Html)

import Network.Wai.Application.Static (defaultWebAppSettings)

import Presentation.Web.Templates (indexTemplate)

import Servant (Get, Handler, Raw, Server, serveDirectoryWith, (:<|>) (..), (:>))
import Servant.HTML.Lucid (HTML)

-- -------------------------------------------------------------------
-- Web API Definitions
-- -------------------------------------------------------------------

-- | API type definition for web interface
--
-- Defines the following endpoints:
--
-- * GET / - Main index page with todos list
-- * GET /static/* - Static files (CSS, JS, etc.)
type WebAPI = Get '[HTML] (Html ()) :<|> "static" :> Raw

-- | Web interface server implementation
webServer :: Server WebAPI
webServer = indexHandler :<|> staticFiles
  where
    -- \| Handler for the main index page
    -- Fetches all todos and renders them using the index template
    indexHandler :: Handler (Html ())
    indexHandler = do
      todos <- liftIO <| runSQLiteRepo getAllTodos
      pure <| indexTemplate todos

    -- \| Handler for static files (CSS, JS, images)
    staticFiles :: Server Raw
    staticFiles = serveDirectoryWith (defaultWebAppSettings "static")
