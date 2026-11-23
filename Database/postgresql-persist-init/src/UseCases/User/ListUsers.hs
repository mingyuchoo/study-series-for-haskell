{-# LANGUAGE FlexibleContexts #-}

module UseCases.User.ListUsers
    ( ListUsersRequest (..)
    , ListUsersResponse (..)
    , ListUsersUseCase (..)
    , listUsers
    ) where

import           Data.Text                          (Text)

import           Domain.Entities.User
import           Domain.Repositories.UserRepository

data ListUsersRequest = ListUsersRequest
     deriving (Eq, Show)

data ListUsersResponse = ListUsersResponse { lrUsers :: [User]
                                           }
     deriving (Eq, Show)

class (Monad m) => ListUsersUseCase m where
  executeListUsers :: ListUsersRequest -> m (Either Text ListUsersResponse)

listUsers :: (UserRepository m) => ListUsersRequest -> m (Either Text ListUsersResponse)
listUsers _ = do
  users <- findAllUsers
  return $ Right $ ListUsersResponse users
