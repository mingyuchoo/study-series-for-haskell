{-# LANGUAGE FlexibleContexts #-}

module UseCases.User.DeleteUser
    ( DeleteUserRequest (..)
    , DeleteUserResponse (..)
    , DeleteUserUseCase (..)
    , deleteUserUseCase
    , deleteUserWithCacheUseCase
    ) where

import           Data.Text                          (Text)

import           Domain.Entities.User
import           Domain.Repositories.UserRepository
import qualified Domain.Repositories.UserRepository as Repo
import           Domain.Services.CacheService

-- Use case input/output DTOs
data DeleteUserRequest = DeleteUserRequest { drUserId :: UserId
                                           }
     deriving (Eq, Show)

data DeleteUserResponse = DeleteUserResponse { drSuccess :: Bool
                                             }
     deriving (Eq, Show)

-- Use case interface
class (Monad m) => DeleteUserUseCase m where
  executeDeleteUser :: DeleteUserRequest -> m (Either Text DeleteUserResponse)

-- Basic implementation without cache
deleteUserUseCase
  :: (UserRepository m) => DeleteUserRequest -> m (Either Text DeleteUserResponse)
deleteUserUseCase req = do
  let userId = drUserId req
  -- Check if user exists first
  maybeUser <- findUserById userId
  case maybeUser of
    Nothing -> return $ Left "User not found"
    Just _ -> do
      success <- Repo.deleteUser userId
      return $ Right $ DeleteUserResponse success

-- Implementation with cache invalidation
deleteUserWithCacheUseCase
  :: (UserRepository m, CacheService m)
  => DeleteUserRequest -> m (Either Text DeleteUserResponse)
deleteUserWithCacheUseCase req = do
  let userId = drUserId req
  -- Check if user exists first
  maybeUser <- findUserById userId
  case maybeUser of
    Nothing -> return $ Left "User not found"
    Just _ -> do
      success <- Repo.deleteUser userId
      if success
        then do
          -- Invalidate cache after successful deletion
          invalidateUser userId
          return $ Right $ DeleteUserResponse True
        else return $ Right $ DeleteUserResponse False
