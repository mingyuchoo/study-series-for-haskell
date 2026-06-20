{-# LANGUAGE OverloadedStrings #-}

module Infrastructure.Database.Connection
  ( createTables
  , initializeDatabase
  ) where

import Database.SQLite.Simple

import Flow ((<|))

-- | 데이터베이스 초기화
initializeDatabase :: IO Connection
initializeDatabase = do
  conn <- open "users.db"
  createTables conn
  return conn

-- | 테이블 생성
createTables :: Connection -> IO ()
createTables conn = do
  execute_ conn createUsersTable
  where
    createUsersTable =
      Query <|
        "CREATE TABLE IF NOT EXISTS users (    \
        \id INTEGER PRIMARY KEY AUTOINCREMENT, \
        \name TEXT NOT NULL,                   \
        \email TEXT NOT NULL UNIQUE,           \
        \password TEXT NOT NULL,               \
        \created_at DATETIME NOT NULL,         \
        \updated_at DATETIME NOT NULL)"
