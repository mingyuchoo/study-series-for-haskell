module Domain.Repository
  ( UserRepository (..)
  ) where

import Domain.Model (User)

-- | 도메인 레포지토리 인터페이스 (포트)
class UserRepository m where
  createUser :: User -> m Bool
  updateUser :: User -> m Bool
  retrieveUser :: Int -> m (Maybe User)
  deleteUser :: Int -> m Bool
  listUsers :: m [User]
