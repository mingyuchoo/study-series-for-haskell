{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}

-- 어댑터 계층(Repository): SQLite 구체 구현
module Adapters.Repository.UserRepositoryAdapter
  ( createUser
  , deleteUser
  , getUser
  , getUsers
  , updateUser
  ) where

import Database.SQLite.Simple (Connection, Only (..), execute, query, query_)
import Database.SQLite.Simple.FromField ()
import Database.SQLite.Simple.FromRow (FromRow (..), field)
import Database.SQLite.Simple.ToRow (ToRow (..))

import Domain.UserModel (User (..))

import Flow ((<|))

-- DB 전용 인스턴스 (도메인 밖)
instance FromRow User where
  fromRow = User <$> field <*> field

instance ToRow User where
  toRow (User Nothing n)  = toRow (Only n)
  toRow (User (Just i) n) = toRow (i, n)

-- 새 사용자 생성
createUser :: Connection -> User -> IO User
createUser conn user = do
  execute conn "INSERT INTO users (name) VALUES (?)" (Only (userName user))
  rows <- query conn "SELECT last_insert_rowid()" () :: IO [Only Integer]
  let newId = case rows of
        [Only n] -> fromIntegral n :: Int
        _        -> 0
  pure <| user {userId = Just newId}

-- ID로 사용자 조회
getUser :: Connection -> Int -> IO (Maybe User)
getUser conn uid = do
  results <- query conn "SELECT id, name FROM users WHERE id = ?" (Only uid)
  case results of
    [u] -> pure <| Just u
    _   -> pure Nothing

-- 모든 사용자 조회
getUsers :: Connection -> IO [User]
getUsers conn = query_ conn "SELECT id, name FROM users"

-- 사용자 업데이트
updateUser :: Connection -> User -> IO Bool
updateUser conn User {..} = case userId of
  Just i -> do
    execute conn "UPDATE users SET name = ? WHERE id = ?" (userName, i)
    [Only (n :: Int)] <- query conn "SELECT changes()" ()
    pure <| n > 0
  Nothing -> pure False

-- 사용자 삭제
deleteUser :: Connection -> Int -> IO Bool
deleteUser conn uid = do
  execute conn "DELETE FROM users WHERE id = ?" (Only uid)
  [Only (n :: Int)] <- query conn "SELECT changes()" ()
  pure <| n > 0
