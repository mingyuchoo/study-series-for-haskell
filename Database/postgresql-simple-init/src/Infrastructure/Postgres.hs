module Infrastructure.Postgres
  ( loadConnectInfoFromEnv
  , withConnection
  ) where

import Control.Exception (bracket)

import Database.PostgreSQL.Simple

import System.Environment (lookupEnv)

import Text.Read (readMaybe)

-- | 환경변수에서 접속정보 로드
-- DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
loadConnectInfoFromEnv :: IO ConnectInfo
loadConnectInfoFromEnv = do
  mHost <- lookupEnv "DB_HOST"
  mPort <- lookupEnv "DB_PORT"
  mName <- lookupEnv "DB_NAME"
  mUser <- lookupEnv "DB_USER"
  mPass <- lookupEnv "DB_PASSWORD"
  let port :: Int
      port = maybe 5432 id (mPort >>= readMaybe)
  pure
    defaultConnectInfo
      { connectHost = maybe "127.0.0.1" id mHost
      , connectPort = fromIntegral port
      , connectDatabase = maybe "postgres" id mName
      , connectUser = maybe "postgres" id mUser
      , connectPassword = maybe "postgres" id mPass
      }

withConnection :: ConnectInfo -> (Connection -> IO a) -> IO a
withConnection ci = bracket (connect ci) close
