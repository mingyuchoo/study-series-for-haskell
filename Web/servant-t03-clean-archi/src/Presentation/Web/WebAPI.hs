{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module Presentation.Web.WebAPI (WebAPI, webServer) where

import Lucid (Html)
import Network.Wai.Application.Static (defaultWebAppSettings)
import Presentation.Web.Templates (indexTemplate)
import Servant (Get, Raw, Server, serveDirectoryWith, (:<|>) (..), (:>))
import Servant.HTML.Lucid (HTML)

type WebAPI = Get '[HTML] (Html ()) :<|> "static" :> Raw

webServer :: Server WebAPI
webServer = pure indexTemplate :<|> serveDirectoryWith (defaultWebAppSettings "static")
