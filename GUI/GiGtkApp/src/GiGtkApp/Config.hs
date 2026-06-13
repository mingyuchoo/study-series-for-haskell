{-# LANGUAGE OverloadedStrings #-}

module GiGtkApp.Config
    ( AppConfig (..)
    , defaultAppConfig
    ) where

import           Data.Int  (Int32)
import           Data.Text (Text)

data AppConfig = AppConfig
    { appApplicationId :: Text
    , appWindowTitle   :: Text
    , appWindowWidth   :: Int32
    , appWindowHeight  :: Int32
    , appButtonLabel   :: Text
    }

defaultAppConfig :: AppConfig
defaultAppConfig = AppConfig
    { appApplicationId = "com.example.GiGtkApp"
    , appWindowTitle = "Hello GTK4"
    , appWindowWidth = 300
    , appWindowHeight = 200
    , appButtonLabel = "Click me"
    }
