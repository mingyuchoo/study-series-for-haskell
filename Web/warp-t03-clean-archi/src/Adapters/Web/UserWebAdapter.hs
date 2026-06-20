{-# LANGUAGE OverloadedStrings #-}

-- 어댑터 계층(Web): WAI 기반 HTTP 인터페이스
module Adapters.Web.UserWebAdapter
  ( app
  ) where

import Application.UserService (UserService (..))

import Data.Aeson (decode, encode, object)
import Data.ByteString.Lazy qualified as LBS
import Data.Text qualified as T

import Domain.UserModel (User (..))

import Flow ((<|))

import Network.HTTP.Types
  ( Status
  , methodDelete
  , methodGet
  , methodPost
  , methodPut
  , status200
  , status201
  , status204
  , status400
  , status404
  )
import Network.HTTP.Types.Header (hContentType)
import Network.Wai
  ( Application
  , Request (..)
  , Response
  , responseFile
  , responseLBS
  , strictRequestBody
  )

import Text.Read (readMaybe)

-- WAI Application 구성
app :: UserService -> Application
app svc request respond = do
  case requestMethod request of
    method | method == methodGet -> do
      case pathInfo request of
        [] -> respond index
        ["api", "users"] -> do
          users <- getUsers svc
          respond <| jsonResponse status200 <| encode users
        ["api", "users", userIdTxt] ->
          case readMaybe (T.unpack userIdTxt) of
            Just uid -> do
              mUser <- getUser svc uid
              case mUser of
                Just u -> respond <| jsonResponse status200 <| encode u
                Nothing -> respond <| jsonResponse status404 <| encode (object [("error", "User not found")])
            Nothing -> respond <| jsonResponse status400 <| encode (object [("error", "Invalid user ID")])
        ["styles.css"] ->
          respond <|
            responseFile
              status200
              [(hContentType, "text/css"), ("Access-Control-Allow-Origin", "*")]
              "www/styles.css"
              Nothing
        ["script.js"] ->
          respond <|
            responseFile
              status200
              [(hContentType, "application/javascript"), ("Access-Control-Allow-Origin", "*")]
              "www/script.js"
              Nothing
        _ ->
          respond <|
            responseFile
              status200
              [(hContentType, "text/html"), ("Access-Control-Allow-Origin", "*")]
              "www/index.html"
              Nothing
    method | method == methodPost -> do
      case pathInfo request of
        ["api", "users"] -> do
          body <- strictRequestBody request
          case decode body of
            Just user -> do
              newUser <- createUser svc user
              respond <| jsonResponse status201 <| encode newUser
            Nothing -> respond <| jsonResponse status400 <| encode (object [("error", "Invalid user data")])
        _ -> respond <| jsonResponse status404 <| encode (object [("error", "Endpoint not found")])
    method | method == methodPut -> do
      case pathInfo request of
        ["api", "users", userIdTxt] ->
          case readMaybe (T.unpack userIdTxt) of
            Just uid -> do
              body <- strictRequestBody request
              case decode body of
                Just user -> do
                  let target = user {userId = Just uid}
                  ok <- updateUser svc target
                  if ok
                    then respond <| jsonResponse status200 <| encode target
                    else respond <| jsonResponse status404 <| encode (object [("error", "User not found")])
                Nothing -> respond <| jsonResponse status400 <| encode (object [("error", "Invalid user data")])
            Nothing -> respond <| jsonResponse status400 <| encode (object [("error", "Invalid user ID")])
        _ -> respond <| jsonResponse status404 <| encode (object [("error", "Endpoint not found")])
    method | method == methodDelete -> do
      case pathInfo request of
        ["api", "users", userIdTxt] ->
          case readMaybe (T.unpack userIdTxt) of
            Just uid -> do
              ok <- deleteUser svc uid
              if ok
                then respond <| jsonResponse status204 <| encode (object [])
                else respond <| jsonResponse status404 <| encode (object [("error", "User not found")])
            Nothing -> respond <| jsonResponse status400 <| encode (object [("error", "Invalid user ID")])
        _ -> respond <| jsonResponse status404 <| encode (object [("error", "Endpoint not found")])
    _ ->
      respond <| jsonResponse status404 <| encode (object [("error", "Method not supported")])

-- JSON 응답 헬퍼
jsonResponse :: Status -> LBS.ByteString -> Response
jsonResponse status =
  responseLBS
    status
    [(hContentType, "application/json"), ("Access-Control-Allow-Origin", "*")]

-- 정적 파일: index.html
index :: Response
index =
  responseFile
    status200
    [(hContentType, "text/html"), ("Access-Control-Allow-Origin", "*")]
    "www/index.html"
    Nothing
