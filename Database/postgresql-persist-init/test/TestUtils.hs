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

rootApiListClient :: ClientEnv -> IO (Either Text [Text])
rootApiListClient clientEnv = do
  return $ Right ["Server ready"]

setupTests :: IO (PGInfo, RedisInfo, ClientEnv, ThreadId)
setupTests = do
  mgr <- newManager tlsManagerSettings
  baseUrl <- parseBaseUrl "http://127.0.0.1:8000"
  let clientEnv = mkClientEnv mgr baseUrl
  _ <- runStdoutLoggingT $ withPostgresqlConn localConnString $ \dbConn -> do
    _ <- runReaderT (runMigrationSilent migrateAll) dbConn
    return ()
  redisConn <- connect localRedisInfo
  _ <- runRedis redisConn flushall
  tid <- forkIO runCachedServer
  waitUntilServerReady clientEnv 30
  return (localConnString, localRedisInfo, clientEnv, tid)

waitUntilServerReady :: ClientEnv -> Int -> IO ()
waitUntilServerReady _ 0 = threadDelay 100000
waitUntilServerReady clientEnv retries = do
  res <- rootApiListClient clientEnv
  case res of
    Right _ -> pure ()
    Left _ -> do
      threadDelay 100000
      waitUntilServerReady clientEnv (retries - 1)
