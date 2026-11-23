{-# LANGUAGE RankNTypes #-}

module Domain.Repositories.UserRepository
    ( UserRepository (..)
    ) where

import           Domain.Entities.User

class (Monad m) => UserRepository m where
  findUserById :: UserId -> m (Maybe User)
  findAllUsers :: m [User]
  saveUser :: User -> m UserId
  updateUser :: UserId -> User -> m Bool
  deleteUser :: UserId -> m Bool
  findUserByEmail :: UserEmail -> m (Maybe User)
