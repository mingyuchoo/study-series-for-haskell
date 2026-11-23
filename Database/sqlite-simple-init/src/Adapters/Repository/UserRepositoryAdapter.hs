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

newtype UserRepositoryAdapter = UserRepositoryAdapter Connection

createUserRepositoryAdapter :: Connection -> UserRepositoryAdapter
createUserRepositoryAdapter = UserRepositoryAdapter

instance UserService UserRepositoryAdapter where
  createUser (UserRepositoryAdapter conn) name email password = do
    now <- getCurrentTime
    let user = User Nothing name email password now now
    execute
      conn
      "INSERT INTO users (name, email, password, created_at, updated_at) VALUES (?, ?, ?, ?, ?)"
      (userName user, userEmail user, userPassword user, createdAt user, updatedAt user)
    rowId <- lastInsertRowId conn
    return <| user {userId = Just (fromIntegral rowId)}

  getAllUsers (UserRepositoryAdapter conn) =
    query_ conn "SELECT id, name, email, password, created_at, updated_at FROM users"

  getUserById (UserRepositoryAdapter conn) uid = do
    users <-
      query
        conn
        "SELECT id, name, email, password, created_at, updated_at FROM users WHERE id = ?"
        (Only uid)
    return <| case users of
      [user] -> Just user
      _      -> Nothing

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
    maybeUser <- getUserById (UserRepositoryAdapter conn) uid
    case maybeUser of
      Just _  -> return True
      Nothing -> return False

  deleteUser (UserRepositoryAdapter conn) uid = do
    executeNamed conn "DELETE FROM users WHERE id = :uid" [":uid" := uid]
    return True
