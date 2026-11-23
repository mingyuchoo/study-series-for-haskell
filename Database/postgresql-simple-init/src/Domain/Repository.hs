module Domain.Repository
  ( UserRepository (..)
  ) where

import Domain.Model (User)

class UserRepository m where
  createUser :: User -> m Bool
  updateUser :: User -> m Bool
  retrieveUser :: Int -> m (Maybe User)
  deleteUser :: Int -> m Bool
  listUsers :: m [User]
