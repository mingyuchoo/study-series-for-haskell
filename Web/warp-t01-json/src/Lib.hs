{-# LANGUAGE OverloadedStrings #-}

module Lib
  ( appRunner
  ) where

import Data.Aeson ()
import Data.ByteString (ByteString)
import Data.ByteString.Lazy (fromStrict)
import Data.Kind ()
import Flow ((<|))
import Network.HTTP.Types (methodDelete, methodGet, methodPost, methodPut, status200)
import Network.HTTP.Types.Header (hContentType)
import Network.Wai
  ( Request
  , Response
  , ResponseReceived
  , pathInfo
  , queryString
  , requestMethod
  , responseFile
  , responseLBS
  )
import Network.Wai.Handler.Warp (run)

-- | Main Function
appRunner :: IO ()
appRunner = do
  putStrLn <| "listening on " <> show port
  run port app
  where
    port :: Int
    port = 4000

-- | Application
app
  :: Request
  -- ^ request
  -> (Response -> IO ResponseReceived)
  -- ^ handler response to IO
  -> IO ResponseReceived
  -- ^ response
app request respond
  | requestMethod request == methodGet =
      let
        reqPathInfo = pathInfo request
        reqQueryString = queryString request
       in
        case (reqPathInfo, reqQueryString) of
          ([], _)                         -> respond <| index
          (["expr"], [("q", Just stuff)]) -> respond <| homeRoute stuff
          (_, _)                          -> respond <| notFoundRoute
  | requestMethod request == methodPost = respond <| post
  | requestMethod request == methodPut = respond <| put
  | requestMethod request == methodDelete = respond <| delete
  | otherwise = respond <| notFoundRoute

-- | POST /
post :: Response
post =
  responseLBS status200 [(hContentType, "text/plain")] "POST method"

-- | PUT /
put :: Response
put =
  responseLBS status200 [(hContentType, "text/plain")] "PUT method"

-- | DELETE /
delete :: Response
delete =
  responseLBS status200 [(hContentType, "text/plain")] "DELETE method"

-- | GET / Index Page
index :: Response
index =
  responseFile status200 [(hContentType, "text/html")] "www/index.html" Nothing

-- | GET / JSON Response
homeRoute :: ByteString -> Response
homeRoute bs =
  responseLBS status200 [(hContentType, "application/json")] (fromStrict bs)

-- | GET / Page not found
notFoundRoute :: Response
notFoundRoute =
  responseLBS status200 [(hContentType, "text/plain")] "Page not found."
