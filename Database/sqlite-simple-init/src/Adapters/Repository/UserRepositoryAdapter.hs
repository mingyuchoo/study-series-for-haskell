{-# LANGUAGE OverloadedStrings #-}

module Adapters.Repository.UserRepositoryAdapter
  ( UserRepositoryAdapter (..)
  , createUserRepositoryAdapter
  ) where

import Application.UserService (UserService (..))

import Data.Time (getCurrentTime)

import Database.SQLite.Simple

import Domain.UserModel (User (..))

import Flow ((<|))

-- | SQLite 저장소 어댑터
newtype UserRepositoryAdapter = UserRepositoryAdapter Connection

-- | 어댑터 생성자
createUserRepositoryAdapter :: Connection -> UserRepositoryAdapter
createUserRepositoryAdapter = UserRepositoryAdapter

-- | UserService 인터페이스 구현
instance UserService UserRepositoryAdapter where
  -- \| 새 사용자 생성
  createUser (UserRepositoryAdapter conn) name email password = do
    now <- getCurrentTime
    let user = User Nothing name email password now now
    execute
      conn
      "INSERT INTO users (name, email, password, created_at, updated_at) VALUES (?, ?, ?, ?, ?)"
      (userName user, userEmail user, userPassword user, createdAt user, updatedAt user)
    rowId <- lastInsertRowId conn
    return <| user {userId = Just (fromIntegral rowId)}

  -- \| 모든 사용자 조회
  getAllUsers (UserRepositoryAdapter conn) =
    query_ conn "SELECT id, name, email, password, created_at, updated_at FROM users"

  -- \| ID로 사용자 조회
  getUserById (UserRepositoryAdapter conn) uid = do
    users <-
      query
        conn
        "SELECT id, name, email, password, created_at, updated_at FROM users WHERE id = ?"
        (Only uid)
    return <| case users of
      [user] -> Just user
      _      -> Nothing

  -- \| 사용자 정보 업데이트
  updateUser (UserRepositoryAdapter conn) uid name email password = do
    now <- getCurrentTime
    executeNamed
      conn
      "UPDATE users SET name = :name, email = :email, password = :pwd, updated_at = :updated WHERE id = :uid"
      [ ":name" := name
      , ":email" := email
      , ":pwd" := password
      , ":updated" := now
      , ":uid" := uid
      ]
    -- 업데이트된 사용자 확인
    maybeUser <- getUserById (UserRepositoryAdapter conn) uid
    case maybeUser of
      Just _  -> return True
      Nothing -> return False

  -- \| 사용자 삭제
  deleteUser (UserRepositoryAdapter conn) uid = do
    executeNamed conn "DELETE FROM users WHERE id = :uid" [":uid" := uid]
    return True
