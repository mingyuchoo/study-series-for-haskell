{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module Application.UserService
    ( BasicUserService (..)
    , CachedUserService (..)
    , runBasicUserService
    , runCachedUserService
    ) where

import           Control.Monad.IO.Class                   (MonadIO)
import           Control.Monad.Reader                     (ReaderT, runReaderT)

import           Domain.Entities.User
import           Domain.Repositories.UserRepository
import           Domain.Services.CacheService

import           Interface.Web.Controllers.UserController
import           Interface.Web.DTOs.UserDTO

import           UseCases.User.CreateUser
import           UseCases.User.DeleteUser                 (DeleteUserRequest (..),
                                                           deleteUserUseCase,
                                                           deleteUserWithCacheUseCase)
import           UseCases.User.GetUser
import           UseCases.User.ListUsers
import           UseCases.User.UpdateUser                 (updateUserUseCase,
                                                           updateUserWithCacheUseCase)

-- Application service without cache
newtype BasicUserService repo a = BasicUserService (ReaderT repo IO a)
     deriving (Applicative, Functor, Monad, MonadIO)

runBasicUserService :: repo -> BasicUserService repo a -> IO a
runBasicUserService repo (BasicUserService action) = runReaderT action repo

-- Application service with cache
data CacheConfig repo cache = CacheConfig repo cache

newtype CachedUserService repo cache a = CachedUserService (ReaderT (CacheConfig repo cache) IO a)
     deriving (Applicative, Functor, Monad, MonadIO)

runCachedUserService :: repo -> cache -> CachedUserService repo cache a -> IO a
runCachedUserService repo cache (CachedUserService action) = runReaderT action (CacheConfig repo cache)

-- Basic service implementation
instance (UserRepository (BasicUserService repo)) => UserController (BasicUserService repo) where
  handleGetUser uid = do
    result <- getUser (GetUserRequest (UserId uid))
    return $ case result of
      Left err                     -> Left err
      Right (GetUserResponse user) -> Right (userToResponseDTO user)

  handleCreateUser dto = do
    result <- createUser (createUserRequestToUseCase dto)
    return $ case result of
      Left err -> Left err
      Right (CreateUserResponse (UserId uid)) -> Right (CreateUserResponseDTO uid)

  handleListUsers = do
    result <- listUsers ListUsersRequest
    return $ case result of
      Left err                        -> Left err
      Right (ListUsersResponse users) -> Right (map userToResponseDTO users)

  handleUpdateUser uid dto = do
    result <- updateUserUseCase (updateUserRequestToUseCase uid dto)
    return $ case result of
      Left err -> Left err
      Right _  -> Right ()

  handleDeleteUser uid = do
    result <- deleteUserUseCase (DeleteUserRequest (UserId uid))
    return $ case result of
      Left err -> Left err
      Right _  -> Right ()

-- Cached service implementation
instance
  ( UserRepository (CachedUserService repo cache)
  , CacheService (CachedUserService repo cache)
  )
  => UserController (CachedUserService repo cache)
  where
  handleGetUser uid = do
    result <- getUserWithCache (GetUserRequest (UserId uid))
    return $ case result of
      Left err                     -> Left err
      Right (GetUserResponse user) -> Right (userToResponseDTO user)

  handleCreateUser dto = do
    result <- createUser (createUserRequestToUseCase dto)
    return $ case result of
      Left err -> Left err
      Right (CreateUserResponse (UserId uid)) -> Right (CreateUserResponseDTO uid)

  handleListUsers = do
    result <- listUsers ListUsersRequest
    return $ case result of
      Left err                        -> Left err
      Right (ListUsersResponse users) -> Right (map userToResponseDTO users)

  handleUpdateUser uid dto = do
    result <- updateUserWithCacheUseCase (updateUserRequestToUseCase uid dto)
    return $ case result of
      Left err -> Left err
      Right _  -> Right ()

  handleDeleteUser uid = do
    result <- deleteUserWithCacheUseCase (DeleteUserRequest (UserId uid))
    return $ case result of
      Left err -> Left err
      Right _  -> Right ()
