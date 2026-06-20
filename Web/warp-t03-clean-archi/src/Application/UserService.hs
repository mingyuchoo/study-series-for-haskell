-- 애플리케이션 계층: 유스케이스 인터페이스 정의
module Application.UserService
  ( UserService (..)
  , mkUserService
  ) where

import Adapters.Repository.UserRepositoryAdapter qualified as Repo

import Database.SQLite.Simple (Connection)

import Domain.UserModel (User)

-- 유스케이스를 한 곳에 모은 인터페이스(레코드)
data UserService = UserService
  { createUser :: User -> IO User
  , getUser    :: Int -> IO (Maybe User)
  , getUsers   :: IO [User]
  , updateUser :: User -> IO Bool
  , deleteUser :: Int -> IO Bool
  }

-- 인프라 의존(연결)을 받아 실제 구현을 구성
mkUserService :: Connection -> UserService
mkUserService conn =
  UserService
    { createUser = Repo.createUser conn
    , getUser = Repo.getUser conn
    , getUsers = Repo.getUsers conn
    , updateUser = Repo.updateUser conn
    , deleteUser = Repo.deleteUser conn
    }
