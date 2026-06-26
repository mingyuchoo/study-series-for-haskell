{-# LANGUAGE TemplateHaskell #-}

-- | 커넥션 풀과 스키마 부트스트랩만 담당한다 (쿼리는 'Luck.Repository.*').
module Luck.DB
  ( newConnPool
  , withConn
  , initSchema
  ) where

import Data.ByteString (ByteString)
import Data.FileEmbed (embedFile)
import Data.Pool (Pool, defaultPoolConfig, newPool, withResource)
import Database.PostgreSQL.Simple
import Database.PostgreSQL.Simple.Types (Query (..))

-- | libpq 접속 문자열로 커넥션 풀을 만든다.
newConnPool :: ByteString -> IO (Pool Connection)
newConnPool url =
  newPool (defaultPoolConfig (connectPostgreSQL url) close 60 10)

-- | 풀에서 커넥션을 빌려 작업을 실행한다.
withConn :: Pool Connection -> (Connection -> IO a) -> IO a
withConn = withResource

-- | 스키마를 멱등적으로 생성한다 (서버 기동 시 자동 호출).
--   DDL의 단일 출처는 @migrations/0001_init.sql@ — 컴파일 타임에 임베드하여
--   in-code 정의와 마이그레이션 파일이 어긋날 여지를 없앤다.
initSchema :: Pool Connection -> IO ()
initSchema pool = withConn pool $ \c -> do
  _ <- execute_ c schemaSql
  pure ()

-- | @migrations/0001_init.sql@ 의 내용을 원시 바이트로 임베드한 스키마 쿼리
--   (UTF-8 한글 주석을 손상 없이 보존).
schemaSql :: Query
schemaSql = Query $(embedFile "migrations/0001_init.sql")
