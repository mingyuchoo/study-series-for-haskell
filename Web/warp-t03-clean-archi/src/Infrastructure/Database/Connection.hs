{-# LANGUAGE OverloadedStrings #-}

-- 인프라 계층: DB 연결 관리
module Infrastructure.Database.Connection
  ( initializeDatabase
  ) where

import Database.SQLite.Simple (Connection, execute_, open)

import Infrastructure.Config.AppConfig (AppConfig (..))

-- 설정을 받아 DB를 초기화하고 연결을 반환
initializeDatabase :: AppConfig -> IO Connection
initializeDatabase cfg = do
  conn <- open (dbPath cfg)
  execute_
    conn
    "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)"
  pure conn
