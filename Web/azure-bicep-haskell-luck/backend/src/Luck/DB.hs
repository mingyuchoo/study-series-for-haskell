{-# LANGUAGE TemplateHaskell #-}

-- | 커넥션 풀과 스키마 부트스트랩만 담당한다 (쿼리는 'Luck.Repository.*').
module Luck.DB
    ( initSchema
    , newConnPool
    , withConn
    ) where

import           Data.ByteString                  (ByteString)
import           Data.FileEmbed                   (embedFile)
import           Data.Pool
    ( Pool
    , defaultPoolConfig
    , newPool
    , withResource
    )
import           Database.PostgreSQL.Simple
import           Database.PostgreSQL.Simple.Types (Query (..))

-- | libpq 접속 문자열로 커넥션 풀을 만든다.
newConnPool :: ByteString -> IO (Pool Connection)
newConnPool url =
  newPool (defaultPoolConfig (connectPostgreSQL url) close 60 10)

-- | 풀에서 커넥션을 빌려 작업을 실행한다.
withConn :: Pool Connection -> (Connection -> IO a) -> IO a
withConn = withResource

-- | 스키마를 멱등적으로 생성/갱신한다 (서버 기동 시 자동 호출).
--   DDL의 단일 출처는 @migrations/*.sql@ — 컴파일 타임에 임베드하여
--   in-code 정의와 마이그레이션 파일이 어긋날 여지를 없앤다.
--   각 파일은 멱등(IF NOT EXISTS / ON CONFLICT)하므로 매 기동마다 순서대로 실행한다.
initSchema :: Pool Connection -> IO ()
initSchema pool = withConn pool $ \c -> mapM_ (execute_ c) migrations

-- | 적용 순서대로 나열한 마이그레이션. 새 마이그레이션은 파일을 추가하고
--   이 목록 끝에 @Query $(embedFile "migrations/NNNN_....sql")@ 한 줄만 더하면 된다.
--   (원시 바이트로 임베드해 UTF-8 한글 주석을 손상 없이 보존한다.)
migrations :: [Query]
migrations =
  [ Query $(embedFile "migrations/0001_init.sql")
  , Query $(embedFile "migrations/0002_admin_and_checklist.sql")
  , Query $(embedFile "migrations/0003_signup_verification.sql")
  , Query $(embedFile "migrations/0004_user_theme.sql")
  , Query $(embedFile "migrations/0005_verification_attempts.sql")
  ]
