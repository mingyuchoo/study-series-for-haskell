{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

-- | 스키마 적용과 연결 설정입니다.
--
-- @schema/schema.sql@을 컴파일 시점에 임베드하므로 실행 파일과 스키마가 어긋날 수
-- 없습니다. 같은 파일이 @docs/generated/db-schema.md@의 생성 원본이기도 합니다.
--
-- 현재는 버전 1만 존재하며 되돌리는 마이그레이션이 없습니다. 이 한계는
-- @docs/tech-debt/active.md@의 @TD-001@로 관리합니다.
module Todo.Store.Migration (
  currentSchemaVersion,
  schemaSql,
  schemaStatements,
  configureConnection,
  applySchema,
  readSchemaVersion,
  withBusyRetry,
) where

import Control.Concurrent (threadDelay)
import Control.Exception (throwIO, try)
import Data.FileEmbed (embedStringFile, makeRelativeToProject)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime)
import Data.Time.Format.ISO8601 (iso8601Show)
import Database.SQLite.Simple (
  Connection,
  Error (..),
  Only (..),
  Query (..),
  SQLError (..),
  execute,
  execute_,
  query_,
  withImmediateTransaction,
 )

-- | 이 코드가 기대하는 스키마 버전입니다.
currentSchemaVersion :: Int
currentSchemaVersion = 1

-- | 컴파일 시점에 임베드한 Canonical 스키마 원본입니다.
schemaSql :: Text
schemaSql = T.pack $(makeRelativeToProject "schema/schema.sql" >>= embedStringFile)

-- | 스키마 원본을 실행 가능한 문장 목록으로 나눕니다.
--
-- 주석 줄을 먼저 제거한 뒤 세미콜론으로 나눕니다. 따라서 주석 안에 세미콜론을
-- 쓰지 않는다는 규칙이 스키마 파일에 적용됩니다.
schemaStatements :: [Query]
schemaStatements =
  map Query
    . filter (not . T.null)
    . map T.strip
    . T.splitOn ";"
    . T.unlines
    . filter (not . T.isPrefixOf "--" . T.stripStart)
    . T.lines
    $ schemaSql

-- | 동시 접근과 참조 무결성을 위한 연결 설정입니다.
--
-- WAL 모드와 busy timeout은 @docs/incidents/INC-2026-001.md@의 조치입니다.
-- 외래 키는 SQLite에서 연결마다 켜야 하므로 여기서 명시적으로 설정합니다.
--
-- __순서가 중요합니다.__ @busy_timeout@을 가장 먼저 설정합니다. 저널 모드를 WAL로
-- 바꾸는 것 자체가 배타적 잠금을 요구하므로, 두 프로세스가 같은 파일을 동시에 처음
-- 열면 한쪽이 그 잠금에서 경합합니다. 그때 timeout이 아직 0이면 대기 없이
-- @SQLITE_BUSY@로 실패합니다. 설정을 뒤에 두면 정작 그 설정이 필요한 작업이
-- 보호받지 못합니다.
configureConnection :: Connection -> IO ()
configureConnection conn = do
  execute_ conn "PRAGMA busy_timeout = 5000"
  _ <- query_ conn "PRAGMA journal_mode = WAL" :: IO [Only Text]
  execute_ conn "PRAGMA foreign_keys = ON"

-- | 스키마를 적용하고 버전을 기록합니다. 이미 적용된 데이터베이스에서도 안전합니다.
--
-- @BEGIN IMMEDIATE@를 사용합니다. 기본값인 지연 트랜잭션은 쓰기 잠금을 나중에
-- 잡는데, 읽기를 먼저 한 뒤 쓰기로 승격하는 순간의 경합에는 busy handler가
-- 적용되지 않습니다. 대기가 교착으로 이어질 수 있어 SQLite가 즉시 실패시킵니다.
applySchema :: Connection -> UTCTime -> IO ()
applySchema conn now = withImmediateTransaction conn $ do
  mapM_ (execute_ conn) schemaStatements
  existing <- readSchemaVersionIn conn
  case existing of
    Just _ -> pure ()
    Nothing ->
      execute
        conn
        "INSERT INTO schema_version (version, applied_at) VALUES (?, ?)"
        (currentSchemaVersion, iso8601Show now)

-- | 기록된 스키마 버전을 읽습니다. 스키마가 없으면 'Nothing'입니다.
readSchemaVersion :: Connection -> IO (Maybe Int)
readSchemaVersion = readSchemaVersionIn

readSchemaVersionIn :: Connection -> IO (Maybe Int)
readSchemaVersionIn conn = do
  rows <- query_ conn "SELECT version FROM schema_version ORDER BY version DESC LIMIT 1"
  pure $ case rows of
    Only version : _ -> Just version
    [] -> Nothing

-- | @SQLITE_BUSY@로 실패한 동작을 정해진 횟수만큼 다시 시도합니다.
--
-- @busy_timeout@이 모든 경합을 덮지 않는 것이 이 함수가 필요한 이유입니다. 특히
-- 저널 모드를 WAL로 바꾸는 일은 배타적 잠금을 요구하면서도 busy handler를 거치지
-- 않고 즉시 @SQLITE_BUSY@를 돌려줍니다. 빈 데이터베이스를 두 프로세스가 동시에
-- 처음 열면 한쪽이 그 지점에서 실패합니다.
--
-- 두 표면을 함께 띄우는 것은 이 제품의 설계이므로(@docs/product/vision.md@),
-- 기동 경합은 예외 상황이 아니라 정상 경로입니다. 따라서 재시도가 우회책이 아니라
-- 정식 처리입니다.
--
-- 재시도는 유한합니다. 잠금을 오래 쥔 다른 프로세스가 있으면 조용히 기다리는 대신
-- 원래 오류를 그대로 올려 사용자가 원인을 볼 수 있게 합니다.
withBusyRetry :: IO a -> IO a
withBusyRetry action = attempt 0 initialDelayMicroseconds
 where
  attempt tries delay = do
    outcome <- try action
    case outcome of
      Right value -> pure value
      Left err
        | tries < maxRetries && isBusy err -> do
            threadDelay delay
            attempt (tries + 1) (min maxDelayMicroseconds (delay * 2))
        | otherwise -> throwIO err

  isBusy :: SQLError -> Bool
  isBusy err = case sqlError err of
    ErrorBusy -> True
    ErrorLocked -> True
    _ -> False

-- | 재시도 상한입니다. 초기 지연부터 배로 늘리며 합계는 대략 2.5초입니다.
maxRetries :: Int
maxRetries = 10

initialDelayMicroseconds :: Int
initialDelayMicroseconds = 20000

maxDelayMicroseconds :: Int
maxDelayMicroseconds = 500000
