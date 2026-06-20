module Presentation.Middleware.LoggingMiddleware
  ( -- * Middleware
    loggingMiddleware
  ) where

-- -------------------------------------------------------------------
-- Imports
-- -------------------------------------------------------------------

import Control.Exception (SomeException, try)

import Data.ByteString (ByteString)
import Data.ByteString qualified as BS
import Data.ByteString.Char8 (unpack)
import Data.IORef (IORef, modifyIORef', newIORef, readIORef)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding qualified as TE
import Data.Time (UTCTime, getCurrentTime)

import Flow ((<|))

import Network.HTTP.Types (statusCode)
import Network.Wai
  ( Middleware
  , Request
  , Response
  , pathInfo
  , requestBody
  , requestHeaders
  , requestMethod
  , responseHeaders
  , responseStatus
  )
import Network.Wai qualified as Wai (rawQueryString)

import System.IO (hFlush, stdout)

-- -------------------------------------------------------------------
-- Middleware Implementation
-- -------------------------------------------------------------------

-- | Middleware that logs HTTP requests and responses to the terminal
loggingMiddleware :: Middleware
loggingMiddleware app req sendResponse = do
  -- Log the request
  time <- getCurrentTime
  logSection "REQUEST" time
  logRequestInfo req

  -- Capture the request body
  (req', bodyContent) <- captureRequestBody req

  -- Log the body content (safely)
  logBodyContent bodyContent
  hFlush stdout -- Ensure output is displayed immediately

  -- Call the application with the modified request and intercept the response
  app req' <| \res -> do
    -- Log the response
    logSection "RESPONSE" time
    logResponseInfo res
    hFlush stdout -- Ensure output is displayed immediately

    -- Send the response to the client
    sendResponse res

-- | Log a section header with timestamp
logSection :: String -> UTCTime -> IO ()
logSection name time = putStrLn <| "\n[" <> name <> "] " <> show time

-- | Log basic request information
logRequestInfo :: Request -> IO ()
logRequestInfo req = do
  let logLine prefix value = putStrLn <| "  " <> prefix <> ": " <> value
  logLine "Method" <| unpack (requestMethod req)
  logLine "Path" <| "/" <> showPath (pathInfo req)
  logLine "Headers" <| show (requestHeaders req)
  logLine "Query Parameters" <| unpack (Wai.rawQueryString req)
  where
    showPath :: [Text] -> String
    showPath [] = ""
    showPath xs = unwords (map T.unpack xs)

-- | Log response information
logResponseInfo :: Response -> IO ()
logResponseInfo res = do
  let logLine prefix value = putStrLn <| "  " <> prefix <> ": " <> value
  logLine "Status" <| show <| statusCode <| responseStatus res
  logLine "Headers" <| show <| responseHeaders res

-- | Log body content safely
logBodyContent :: ByteString -> IO ()
logBodyContent body = do
  let logLine prefix value = putStrLn <| "  " <> prefix <> ": " <> value
  logLine "Body Length" <| show (BS.length body) <> " bytes"

  if BS.null body
    then logLine "Body" "<empty>"
    else do
      -- Try to decode as UTF-8 text, fallback to showing as binary if it fails
      result <- try (pure $! TE.decodeUtf8 body) :: IO (Either SomeException Text)
      case result of
        Right text -> logLine "Body" <| T.unpack text
        Left _     -> logLine "Body" "<binary data>"

-- | Capture the request body and create a new request with the body restored
captureRequestBody :: Request -> IO (Request, ByteString)
captureRequestBody req = do
  -- Read all body chunks
  bodyChunks <- readRequestBodyChunks req

  -- Convert chunks to a single ByteString
  let bodyContent = BS.concat bodyChunks

  -- Create a reference to store the body for later use
  bodyRef <- newIORef [bodyContent]

  -- Create a new request with the body restored
  let req' = req {requestBody = getBodyChunk bodyRef}

  pure (req', bodyContent)

-- | Read all chunks from the request body
-- Uses a more idiomatic recursive approach
readRequestBodyChunks :: Request -> IO [ByteString]
readRequestBodyChunks = go []
  where
    go :: [ByteString] -> Request -> IO [ByteString]
    go acc req = do
      chunk <- requestBody req
      if BS.null chunk
        then pure (reverse acc)
        else go (chunk : acc) req

-- | Create a requestBody function that returns chunks from our stored body
getBodyChunk :: IORef [ByteString] -> IO ByteString
getBodyChunk ref = do
  chunks <- readIORef ref
  case chunks of
    [] -> pure BS.empty
    (x : xs) -> do
      modifyIORef' ref (const xs)
      pure x
