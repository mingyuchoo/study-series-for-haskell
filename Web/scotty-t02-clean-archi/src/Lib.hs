{-# LANGUAGE OverloadedStrings #-}

module Lib
  ( shortener
  ) where

import Adapters.Web.Controller.UrlController
  ( createUrlHandler
  , homeHandler
  , redirectHandler
  )

import Infrastructure.Repository.RedisUrlRepository (createRedisConnection)

import Web.Scotty

-- | shortener
shortener :: IO ()
shortener = do
  redisConn <- createRedisConnection
  putStrLn "Connected to Redis"
  putStrLn "Starting URL Shortener on port 8000..."
  scotty 8000 $ do
    get "/" $ homeHandler redisConn
    post "/" $ createUrlHandler redisConn
    get "/:n" $ redirectHandler redisConn
