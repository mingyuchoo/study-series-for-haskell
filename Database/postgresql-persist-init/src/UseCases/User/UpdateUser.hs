{-# LANGUAGE FlexibleContexts #-}

module UseCases.User.UpdateUser
    ( UpdateUserRequest (..)
    , UpdateUserResponse (..)
    , UpdateUserUseCase (..)
    , updateUserUseCase
    , updateUserWithCacheUseCase
    ) where

import           Data.Text                          (Text)

import           Domain.Entities.User
import           Domain.Repositories.UserRepository
import qualified Domain.Repositories.UserRepository as Repo
import           Domain.Services.CacheService

-- Use case input/output DTOs
data UpdateUserRequest = UpdateUserRequest { urUserId     :: UserId
                                           , urName       :: Maybe Text
                                           , urEmail      :: Maybe Text
                                           , urAge        :: Maybe Int
                                           , urOccupation :: Maybe Text
                                           }
     deriving (Eq, Show)

data UpdateUserResponse = UpdateUserResponse { urSuccess :: Bool
                                             }
     deriving (Eq, Show)

-- Use case interface
class (Monad m) => UpdateUserUseCase m where
  executeUpdateUser :: UpdateUserRequest -> m (Either Text UpdateUserResponse)

-- Basic implementation without cache
updateUserUseCase
  :: (UserRepository m) => UpdateUserRequest -> m (Either Text UpdateUserResponse)
updateUserUseCase req = do
  let userId = urUserId req
  maybeUser <- findUserById userId
  case maybeUser of
    Nothing -> return $ Left "User not found"
    Just user -> do
      let updatedUser = applyUpdates user req
      case validateUser updatedUser of
        Left err -> return $ Left err
        Right validUser -> do
          success <- Repo.updateUser userId validUser
          return $ Right $ UpdateUserResponse success

-- Implementation with cache invalidation
updateUserWithCacheUseCase
  :: (UserRepository m, CacheService m)
  => UpdateUserRequest -> m (Either Text UpdateUserResponse)
updateUserWithCacheUseCase req = do
  let userId = urUserId req
  maybeUser <- findUserById userId
  case maybeUser of
    Nothing -> return $ Left "User not found"
    Just user -> do
      let updatedUser = applyUpdates user req
      case validateUser updatedUser of
        Left err -> return $ Left err
        Right validUser -> do
          success <- Repo.updateUser userId validUser
          if success
            then do
              -- Invalidate cache after successful update
              invalidateUser userId
              return $ Right $ UpdateUserResponse True
            else return $ Right $ UpdateUserResponse False

-- Helper function to apply partial updates
applyUpdates :: User -> UpdateUserRequest -> User
applyUpdates user req =
  user
    { userName = maybe (userName user) UserName (urName req)
    , userEmail = maybe (userEmail user) UserEmail (urEmail req)
    , userAge = maybe (userAge user) UserAge (urAge req)
    , userOccupation = maybe (userOccupation user) UserOccupation (urOccupation req)
    }
