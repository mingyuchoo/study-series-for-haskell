{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators     #-}

module Interface.Web.Controllers.UserController
    ( UserAPI
    , UserController (..)
    , userServer
    ) where

import           Control.Monad.Error.Class  (throwError)

import qualified Data.ByteString.Lazy       as LBS
import           Data.Char                  (ord)
import           Data.Int                   (Int64)
import           Data.Text                  (Text)
import qualified Data.Text                  as T

import           Interface.Web.DTOs.UserDTO

import           Servant.API
import           Servant.Server

-- API definition
type UserAPI =
  "users" :> Capture "userid" Int64 :> Get '[JSON] UserResponseDTO
    :<|> "users" :> ReqBody '[JSON] CreateUserRequestDTO :> Post '[JSON] CreateUserResponseDTO
    :<|> "users" :> Get '[JSON] [UserResponseDTO]
    :<|> "users" :> Capture "userid" Int64 :> ReqBody '[JSON] UpdateUserRequestDTO :> PutNoContent
    :<|> "users"
      :> Capture "userid" Int64
      :> ReqBody '[JSON] UpdateUserRequestDTO
      :> PatchNoContent
    :<|> "users" :> Capture "userid" Int64 :> DeleteNoContent

-- Controller interface
class (Monad m) => UserController m where
  handleGetUser :: Int64 -> m (Either Text UserResponseDTO)
  handleCreateUser :: CreateUserRequestDTO -> m (Either Text CreateUserResponseDTO)
  handleListUsers :: m (Either Text [UserResponseDTO])
  handleUpdateUser :: Int64 -> UpdateUserRequestDTO -> m (Either Text ())
  handleDeleteUser :: Int64 -> m (Either Text ())

-- Server implementation
userServer :: (UserController Handler) => ServerT UserAPI Handler
userServer =
  getUserHandler
    :<|> createUserHandler
    :<|> listUsersHandler
    :<|> updateUserHandler
    :<|> patchUserHandler
    :<|> deleteUserHandler

-- Handler implementations
getUserHandler :: (UserController Handler) => Int64 -> Handler UserResponseDTO
getUserHandler uid = do
  result <- handleGetUser uid
  case result of
    Left err   -> throwError $ err404 {errBody = fromString $ T.unpack err}
    Right user -> return user

createUserHandler
  :: (UserController Handler) => CreateUserRequestDTO -> Handler CreateUserResponseDTO
createUserHandler req = do
  result <- handleCreateUser req
  case result of
    Left err       -> throwError $ err400 {errBody = fromString $ T.unpack err}
    Right response -> return response

listUsersHandler :: (UserController Handler) => Handler [UserResponseDTO]
listUsersHandler = do
  result <- handleListUsers
  case result of
    Left err    -> throwError $ err500 {errBody = fromString $ T.unpack err}
    Right users -> return users

updateUserHandler
  :: (UserController Handler) => Int64 -> UpdateUserRequestDTO -> Handler NoContent
updateUserHandler uid req = do
  result <- handleUpdateUser uid req
  case result of
    Left err -> throwError $ err400 {errBody = fromString $ T.unpack err}
    Right _  -> return NoContent

patchUserHandler
  :: (UserController Handler) => Int64 -> UpdateUserRequestDTO -> Handler NoContent
patchUserHandler uid req = do
  result <- handleUpdateUser uid req
  case result of
    Left err -> throwError $ err400 {errBody = fromString $ T.unpack err}
    Right _  -> return NoContent

deleteUserHandler :: (UserController Handler) => Int64 -> Handler NoContent
deleteUserHandler uid = do
  result <- handleDeleteUser uid
  case result of
    Left err -> throwError $ err404 {errBody = fromString $ T.unpack err}
    Right _  -> return NoContent

-- Helper function
fromString :: String -> LBS.ByteString
fromString = LBS.pack . map (fromIntegral . ord)
