{-# LANGUAGE OverloadedStrings #-}

module Adapters.Web.Controller.UrlController
  ( createUrlHandler
  , homeHandler
  , redirectHandler
  ) where

import Adapters.Web.View.UrlView (renderHomePage)

import Application.UseCase.ListUrls (listUrls)
import Application.UseCase.RetrieveUrl (retrieveUrl)
import Application.UseCase.ShortenUrl (shortenUrl)

import Control.Monad.IO.Class (liftIO)

import Data.Text.Lazy qualified as LT

import Database.Redis (Connection)

import Domain.Entity.Url (TempUrl (..), Url (..), mkUrl)

import Infrastructure.Repository.RedisUrlRepository (runRedisUrlRepo)

import Network.HTTP.Types (status400, status404)

import Web.Scotty

homeHandler :: Connection -> ActionM ()
homeHandler redisConn = do
  urls <- liftIO $ runRedisUrlRepo listUrls redisConn
  html $ renderHomePage urls

createUrlHandler :: Connection -> ActionM ()
createUrlHandler redisConn = do
  urlText <- formParam "url"
  case mkUrl urlText of
    Nothing -> do
      status status400
      text "Invalid URL"
      finish
    Just url -> do
      _ <- liftIO $ runRedisUrlRepo (shortenUrl url) redisConn
      redirect "/"

redirectHandler :: Connection -> ActionM ()
redirectHandler redisConn = do
  urlId <- pathParam "n"
  maybeUrl <- liftIO $ runRedisUrlRepo (retrieveUrl urlId) redisConn
  case maybeUrl of
    Just url -> redirect (LT.fromStrict $ originalUrl url)
    Nothing -> do
      status status404
      text "not found"
      finish
