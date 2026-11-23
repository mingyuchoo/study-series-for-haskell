{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators     #-}

module Infrastructure.Web.Server
    ( FullAPI
    , runBasicServer
    , runCachedServer
    , runEsqueletoServer
    ) where

import           Application.UserService

import           Control.Monad.Error.Class                                (throwError)
import           Control.Monad.IO.Class                                   (liftIO)

import qualified Data.ByteString.Lazy                                     as LBS
import           Data.Char                                                (ord)
import           Data.Int                                                 (Int64)
import           Data.Proxy                                               (Proxy (..))
import           Data.Text                                                (Text)
import qualified Data.Text                                                as T

import qualified Domain.Entities.User                                     as DU
import           Domain.Repositories.UserRepository

import           Infrastructure.Cache.Redis.CacheServiceImpl
import           Infrastructure.Persistence.PostgreSQL.UserRepositoryImpl

import           Interface.Web.Controllers.UserController
import           Interface.Web.DTOs.UserDTO

import           Network.Wai.Handler.Warp                                 (run)

import           Servant.API
import           Servant.Server

type FullAPI =
  Get '[JSON] [Text]
    :<|> UserAPI

fullAPI :: Proxy FullAPI
fullAPI = Proxy

rootHandler :: Handler [Text]
rootHandler =
  return
    [ "/"
    , "GET /users"
    , "POST /users"
    , "GET /users/{id}"
    , "PUT /users/{id}"
    , "PATCH /users/{id}"
    , "DELETE /users/{id}"
    ]

basicServer :: Server FullAPI
basicServer = rootHandler :<|> basicUserAPI
  where
    basicUserAPI :: Server UserAPI
    basicUserAPI =
      getUserHandler
        :<|> createUserHandler
        :<|> listUsersHandler
        :<|> updateUserHandler
        :<|> patchUserHandler
        :<|> deleteUserHandler

    getUserHandler :: Int64 -> Handler UserResponseDTO
    getUserHandler uid = do
      result <- liftIO $ runPostgreSQLUserRepository localConnString $ do
        user <- findUserById (DU.UserId uid)
        return $ case user of
          Nothing -> Left "User not found"
          Just u  -> Right (userToResponseDTO u)
      case result of
        Left err -> throwError $ err404 {errBody = fromString (T.unpack err)}
        Right userDto -> return userDto

    createUserHandler :: CreateUserRequestDTO -> Handler CreateUserResponseDTO
    createUserHandler req = do
      result <- liftIO $ runPostgreSQLUserRepository localConnString $ do
        existingUser <- findUserByEmail (DU.UserEmail $ crEmail req)
        case existingUser of
          Just _ -> return $ Left "User with this email already exists"
          Nothing -> do
            case DU.mkUser (crName req) (crEmail req) (crAge req) (crOccupation req) of
              Left err -> return $ Left err
              Right user -> do
                userId <- saveUser user
                return $ Right $ CreateUserResponseDTO (let DU.UserId uid = userId in uid)
      case result of
        Left err -> throwError $ err400 {errBody = fromString (T.unpack err)}
        Right response -> return response

    listUsersHandler :: Handler [UserResponseDTO]
    listUsersHandler = do
      users <- liftIO $ runPostgreSQLUserRepository localConnString findAllUsers
      return $ map userToResponseDTO users

    updateUserHandler :: Int64 -> UpdateUserRequestDTO -> Handler NoContent
    updateUserHandler uid req = do
      result <- liftIO $ runPostgreSQLUserRepository localConnString $ do
        maybeUser <- findUserById (DU.UserId uid)
        case maybeUser of
          Nothing -> return $ Left "User not found"
          Just existingUser -> do
            let updatedUser = updateUserFields existingUser req
            success <- updateUser (DU.UserId uid) updatedUser
            return $ if success then Right () else Left "Update failed"
      case result of
        Left err -> throwError $ err400 {errBody = fromString (T.unpack err)}
        Right _  -> return NoContent

    patchUserHandler :: Int64 -> UpdateUserRequestDTO -> Handler NoContent
    patchUserHandler = updateUserHandler
    deleteUserHandler :: Int64 -> Handler NoContent
    deleteUserHandler uid = do
      result <- liftIO $ runPostgreSQLUserRepository localConnString $ do
        success <- deleteUser (DU.UserId uid)
        return $ if success then Right () else Left "Delete failed"
      case result of
        Left err -> throwError $ err404 {errBody = fromString (T.unpack err)}
        Right _  -> return NoContent

    updateUserFields :: DU.User -> UpdateUserRequestDTO -> DU.User
    updateUserFields user req =
      user
        { DU.userName = maybe (DU.userName user) DU.UserName (urName req)
        , DU.userEmail = maybe (DU.userEmail user) DU.UserEmail (urEmail req)
        , DU.userAge = maybe (DU.userAge user) DU.UserAge (urAge req)
        , DU.userOccupation = maybe (DU.userOccupation user) DU.UserOccupation (urOccupation req)
        }

    fromString :: String -> LBS.ByteString
    fromString = LBS.pack . map (fromIntegral . ord)

cachedServer :: Server FullAPI
cachedServer = basicServer

runBasicServer :: IO ()
runBasicServer = do
  putStrLn "Starting Basic Server on port 8000..."
  run 8000 (serve fullAPI basicServer)

runCachedServer :: IO ()
runCachedServer = do
  putStrLn "Starting Cached Server on port 8000..."
  run 8000 (serve fullAPI cachedServer)

runEsqueletoServer :: IO ()
runEsqueletoServer = do
  putStrLn "Starting Esqueleto Server on port 8000..."
  run 8000 (serve fullAPI basicServer)
