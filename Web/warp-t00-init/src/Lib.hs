{-# LANGUAGE OverloadedStrings #-}

module Lib
  ( someFunc
  ) where

import Data.Kind ()

import Flow ((<|))

import Network.HTTP.Types (status200, status404)
import Network.HTTP.Types.Header (hContentType)
import Network.Wai
  ( Request
  , Response
  , ResponseReceived
  , rawPathInfo
  , responseFile
  , responseLBS
  )
import Network.Wai.Handler.Warp (run)

someFunc :: IO ()
someFunc = do
  putStrLn <| "listening on " ++ show port
  -- run port app1
  -- run port app2
  run port app3
  where
    port :: Int
    port = 4000

app1
  :: Request
  -- ^ request
  -> (Response -> IO ResponseReceived)
  -- ^ handler response to IO
  -> IO ResponseReceived
  -- ^ response
app1 _request respond = do
  putStrLn "app1> Received an HTTP request!"
  respond <| responseLBS status200 [(hContentType, "text/plain")] "Hello, World!\n"

app2
  :: Request
  -- ^ request
  -> (Response -> IO ResponseReceived)
  -- ^ handler response to IO
  -> IO ResponseReceived
  -- ^ response
app2 _request respond = do
  putStrLn "app2> Received an HTTP request!"
  respond <| responseFile status200 [(hContentType, "text/html")] "index.html" Nothing

app3
  :: Request
  -- ^ request
  -> (Response -> IO ResponseReceived)
  -- ^ handler response to IO
  -> IO ResponseReceived
  -- ^ response
app3 request respond = do
  putStrLn "app3> Received an HTTP request!"
  respond <| case rawPathInfo request of
    "/"     -> index
    "/raw/" -> plainIndex
    _       -> notFound

index :: Response
index = responseFile status200 [(hContentType, "text/html")] "index.html" Nothing

plainIndex :: Response
plainIndex = responseFile status200 [(hContentType, "text/plain")] "index.html" Nothing

notFound :: Response
notFound = responseLBS status404 [(hContentType, "text/plain")] "404 - Not Found"
