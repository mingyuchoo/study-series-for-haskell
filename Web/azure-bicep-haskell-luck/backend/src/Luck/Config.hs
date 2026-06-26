-- | 환경변수에서 애플리케이션 설정을 읽어온다.
module Luck.Config
  ( Config (..)
  , loadConfig
  ) where

import Data.ByteString (ByteString)
import Data.ByteString.Char8 qualified as BS
import Data.Maybe (fromMaybe)
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

-- | 런타임 설정.
data Config = Config
  { cfgDbUrl :: ByteString
  -- ^ PostgreSQL libpq 접속 문자열
  , cfgJwtSecret :: ByteString
  -- ^ JWT 서명용 비밀키
  , cfgPort :: Int
  -- ^ HTTP 리슨 포트
  }

-- | 환경변수에서 설정을 읽고, 없으면 개발용 기본값을 사용한다.
loadConfig :: IO Config
loadConfig = do
  dbUrl <- lookupEnv "DATABASE_URL"
  secret <- lookupEnv "JWT_SECRET"
  port <- lookupEnv "PORT"
  pure
    Config
      { cfgDbUrl =
          BS.pack (fromMaybe "postgresql://luck:luck@localhost:5432/luck" dbUrl)
      , cfgJwtSecret =
          BS.pack (fromMaybe "change-me-in-production-please-use-a-long-random-secret" secret)
      , cfgPort = fromMaybe 8080 (port >>= readMaybe)
      }
