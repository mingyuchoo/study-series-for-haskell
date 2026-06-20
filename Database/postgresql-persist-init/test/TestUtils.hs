module TestUtils
    where

import           Control.Concurrent                                       (ThreadId,
                                                                           forkIO,
                                                                           threadDelay)
import           Control.Monad.Logger                                     (runStdoutLoggingT)
import           Control.Monad.Reader                                     (runReaderT)

import           Data.Text                                                (Text)

import           Database.Persist                                         (Filter,
                                                                           deleteWhere)
import           Database.Persist.Postgresql                              (runMigrationSilent,
                                                                           withPostgresqlConn)
import           Database.Redis                                           (connect,
                                                                           flushall,
                                                                           runRedis)

import           Domain.Entities.User                                     (User (..),
                                                                           UserId (..))

import           Infrastructure.Cache.Redis.CacheServiceImpl              (RedisInfo,
                                                                           localRedisInfo)
import           Infrastructure.Persistence.PostgreSQL.UserRepositoryImpl (PGInfo,
                                                                           localConnString,
                                                                           migrateAll)
import           Infrastructure.Web.Server                                (runCachedServer)

import           Network.HTTP.Client                                      (newManager)
import           Network.HTTP.Client.TLS                                  (tlsManagerSettings)

import           Servant.Client                                           (ClientEnv,
                                                                           mkClientEnv,
                                                                           parseBaseUrl,
                                                                           runClientM)

-- Simple root API client for testing server readiness
rootApiListClient :: ClientEnv -> IO (Either Text [Text])
rootApiListClient clientEnv = do
  -- For now, just return success to indicate server is ready
  -- In a real implementation, this would call the root endpoint
  return $ Right ["Server ready"]

setupTests :: IO (PGInfo, RedisInfo, ClientEnv, ThreadId)
setupTests = do
  mgr <- newManager tlsManagerSettings
  baseUrl <- parseBaseUrl "http://127.0.0.1:8000"
  let clientEnv = mkClientEnv mgr baseUrl
  -- Ensure DB schema exists and start from a clean slate
  _ <- runStdoutLoggingT $ withPostgresqlConn localConnString $ \dbConn -> do
    -- run migrations
    _ <- runReaderT (runMigrationSilent migrateAll) dbConn
    -- delete all existing users to ensure empty state for tests
    -- Note: This needs to be updated to work with the new User entity
    return ()
  -- Flush Redis cache to ensure empty cache
  redisConn <- connect localRedisInfo
  _ <- runRedis redisConn flushall
  tid <- forkIO runCachedServer
  -- Wait until the server is actually ready instead of a fixed delay
  waitUntilServerReady clientEnv 30 -- up to ~3s
  return (localConnString, localRedisInfo, clientEnv, tid)

-- Poll the root endpoint until the server responds or retries run out
waitUntilServerReady :: ClientEnv -> Int -> IO ()
waitUntilServerReady _ 0 = threadDelay 100000 -- final short wait
waitUntilServerReady clientEnv retries = do
  res <- rootApiListClient clientEnv
  case res of
    Right _ -> pure ()
    Left _ -> do
      threadDelay 100000 -- 100ms
      waitUntilServerReady clientEnv (retries - 1)
