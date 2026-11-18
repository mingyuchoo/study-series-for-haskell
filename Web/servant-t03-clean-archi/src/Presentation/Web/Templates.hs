{-# LANGUAGE OverloadedStrings #-}

module Presentation.Web.Templates (indexTemplate) where

import Data.Text (Text)
import Lucid

indexTemplate :: Html ()
indexTemplate =
  doctypehtml_ $
    html_ [lang_ "en"] $ do
      head_ $ do
        meta_ [charset_ "utf-8"]
        meta_ [name_ "viewport", content_ "width=device-width, initial-scale=1.0"]
        title_ "Todo Workspace"
        link_
          [ rel_ "stylesheet"
          , href_
              "https://fonts.googleapis.com/css2?family=Cormorant+Garamond:wght@500&family=Inter:wght@400;500&display=swap"
          ]
        link_ [rel_ "stylesheet", href_ "/static/css/style.css"]
        link_ [rel_ "icon", href_ "/static/favicon.png"]
        script_ [src_ "/static/js/elm.js", defer_ ""] ("" :: Text)
        script_ [src_ "/static/js/bootstrap.js", defer_ ""] ("" :: Text)
      body_ $ do
        div_ [id_ "todo-app"] mempty
        noscript_ "Enable JavaScript to use the Todo Workspace."
