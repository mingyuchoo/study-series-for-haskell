{-# LANGUAGE FlexibleContexts #-}

module UseCases.User.GetUser
    ( GetUserRequest (..)
    , GetUserResponse (..)
    , GetUserUseCase (..)
    , getUser
    , getUserWithCache
    ) where

import           Data.Text                          (Text)

import           Domain.Entities.User
import           Domain.Repositories.UserRepository
import           Domain.Services.CacheService

data GetUserRequest = GetUserRequest { grUserId :: UserId
                                     }
     deriving (Eq, Show)

data GetUserResponse = GetUserResponse { grUser :: User
                                       }
     deriving (Eq, Show)

class (Monad m) => GetUserUseCase m where
  executeGetUser :: GetUserRequest -> m (Either Text GetUserResponse)

getUser :: (UserRepository m) => GetUserRequest -> m (Either Text GetUserResponse)
getUser req = do
  maybeUser <- findUserById (grUserId req)
  case maybeUser of
    Nothing   -> return $ Left "User not found"
    Just user -> return $ Right $ GetUserResponse user

getUserWithCache
  :: (UserRepository m, CacheService m) => GetUserRequest -> m (Either Text GetUserResponse)
getUserWithCache req = do
  let userId = grUserId req
  cachedUser <- getCachedUser userId
  case cachedUser of
    Just user -> return $ Right $ GetUserResponse user
    Nothing -> do
      maybeUser <- findUserById userId
      case maybeUser of
        Nothing -> return $ Left "User not found"
        Just user -> do
          cacheUser userId user
          return $ Right $ GetUserResponse user
