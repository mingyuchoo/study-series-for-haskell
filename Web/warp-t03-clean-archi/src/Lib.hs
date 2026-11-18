{-# LANGUAGE OverloadedStrings #-}

module Lib
  ( appRunner
  , withUserApplication
  ) where

import Adapters.Web.UserWebAdapter (app)

import Application.UserService (mkUserService)

import Control.Exception (bracket)

import Database.SQLite.Simple (close)

import Flow ((<|))

import Infrastructure.Config.AppConfig (AppConfig (..), defaultConfig)
import Infrastructure.Database.Connection (initializeDatabase)

import Network.Wai (Application)
import Network.Wai.Handler.Warp (run)

appRunner :: IO ()
appRunner = do
  let cfg = defaultConfig
  putStrLn <| "listening on " <> show (port cfg)
  withUserApplication (dbPath cfg) (run (port cfg))

withUserApplication :: FilePath -> (Application -> IO a) -> IO a
withUserApplication databasePath useApplication =
  bracket (initializeDatabase defaultConfig {dbPath = databasePath}) close $ \connection ->
    useApplication (app (mkUserService connection))
