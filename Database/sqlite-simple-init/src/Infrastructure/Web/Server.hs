{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Infrastructure.Web.Server
  ( startServer
  ) where

import Application.UserService (UserService (..))

import Control.Exception (SomeException, try)

import Data.Aeson (object, (.=))

import Database.SQLite.Simple (Error (..), SQLError (..))

import Domain.UserModel (User (..))

import Flow ((<|))

import Network.HTTP.Types
import Network.Wai.Middleware.Cors

import Web.Scotty

-- | Web server implementation
startServer :: (UserService a) => a -> IO ()
startServer userService =
  scotty 8000 <| do
    -- \| Enable CORS
    middleware simpleCors

    -- \| Serve static files
    get "/favicon.ico" <| do
      setHeader "Content-Type" "image/x-icon"
      file "static/favicon.ico"

    -- \| Serve CSS files
    get "/css/:filename" <| do
      filename <- pathParam "filename"
      setHeader "Content-Type" "text/css"
      file ("static/css/" <> filename)

    -- \| Serve JavaScript files
    get "/js/:filename" <| do
      filename <- pathParam "filename"
      setHeader "Content-Type" "application/javascript"
      file ("static/js/" <> filename)

    -- \| Serve HTML files
    get "/index.html" <| do
      setHeader "Content-Type" "text/html"
      file "static/index.html"

    -- \| Redirect root to index.html
    get "/" <| do
      redirect "/index.html"

    -- \| Get all users
    get "/users" <| do
      users <- liftIO <| getAllUsers userService
      json users

    -- \| Get user by ID
    get "/users/:id" <| do
      uid <- pathParam "id"
      maybeUser <- liftIO <| getUserById userService uid
      case maybeUser of
        Just user -> json user
        Nothing   -> status status404

    -- \| Create new user
    post "/users" <| do
      name <- formParam "name"
      email <- formParam "email"
      password <- formParam "password"
      case () of
        _
          | null name || null email || null password -> do
              status status400
              json <| object ["error" .= ("name, email and password are required" :: String)]
          | otherwise -> do
              result <-
                liftIO <| (try (createUser userService name email password) :: IO (Either SQLError User))
              case result of
                Right user -> do
                  status status201
                  json user
                Left (SQLError {sqlError = ErrorConstraint}) -> do
                  status status409
                  json <| object ["error" .= ("Email already exists" :: String)]
                Left e -> do
                  status status500
                  json <| object ["error" .= (show e :: String)]

    -- \| Update user
    put "/users/:id" <| do
      uid <- pathParam "id"
      name <- formParam "name"
      email <- formParam "email"
      password <- formParam "password"
      case () of
        _
          | null name || null email || null password -> do
              status status400
              json <| object ["error" .= ("name, email and password are required" :: String)]
          | otherwise -> do
              result <-
                ( liftIO <|
                    (try (updateUser userService uid name email password) :: IO (Either SQLError Bool))
                )
              case result of
                Right success | success -> do
                  userResult <-
                    liftIO <| (try (getUserById userService uid) :: IO (Either SomeException (Maybe User)))
                  case userResult of
                    Right maybeUser ->
                      case maybeUser of
                        Just user -> do
                          status status200
                          json user
                        Nothing -> do
                          status status404
                          json <| object ["error" .= ("User not found after update" :: String)]
                    Left (e :: SomeException) -> do
                      status status500
                      json <| object ["error" .= (show e :: String)]
                Right _ -> do
                  status status404
                  json <| object ["error" .= ("User not found" :: String)]
                Left (SQLError {sqlError = ErrorConstraint}) -> do
                  status status409
                  json <| object ["error" .= ("Email already exists" :: String)]
                Left e -> do
                  status status500
                  json <| object ["error" .= (show e :: String)]

    -- \| Delete user
    delete "/users/:id" <| do
      uid <- pathParam "id"
      result <- liftIO <| try <| deleteUser userService uid
      case result of
        Right success
          | success ->
              status status204
        Right _ -> do
          status status404
          json <| object ["error" .= ("User not found" :: String)]
        Left (e :: SomeException) -> do
          status status500
          json <| object ["error" .= (show e :: String)]
