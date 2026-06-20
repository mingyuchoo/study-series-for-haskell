{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}

module Infrastructure.Cache.Redis.CacheServiceImpl
    ( RedisCacheService (..)
    , RedisInfo
    , localRedisInfo
    , runRedisCacheService
    ) where

import           Control.Exception            (SomeException, try)
import           Control.Monad.IO.Class       (MonadIO, liftIO)
import           Control.Monad.Reader         (ReaderT, ask, runReaderT)

import           Data.ByteString              (ByteString)
import           Data.ByteString.Char8        (pack, unpack)
import           Data.Int                     (Int64)

import           Database.Redis

import           Domain.Entities.User
import           Domain.Services.CacheService

-- Infrastructure types
type RedisInfo = ConnectInfo

localRedisInfo :: RedisInfo
localRedisInfo = defaultConnectInfo

-- Cache service implementation monad
newtype RedisCacheService a = RedisCacheService (ReaderT RedisInfo IO a)
     deriving (Applicative, Functor, Monad, MonadIO)

-- Run the cache service
runRedisCacheService :: RedisInfo -> RedisCacheService a -> IO a
runRedisCacheService redisInfo (RedisCacheService action) = runReaderT action redisInfo

-- Helper functions for Redis operations
runRedisAction :: RedisInfo -> Redis a -> IO a
runRedisAction redisInfo action = do
  connection <- connect redisInfo
  runRedis connection action

-- Serialize user for caching (simple show/read for now)
serializeUser :: User -> ByteString
serializeUser user = pack $ show user

-- Deserialize user from cache
deserializeUser :: Int64 -> ByteString -> Maybe User
deserializeUser uid userString =
  case reads (unpack userString) of
    [(user, "")] -> Just user {userId = Just (UserId uid)}
    _            -> Nothing

-- Cache service implementation
instance CacheService RedisCacheService where
  cacheUser (UserId uid) user = RedisCacheService $ do
    redisInfo <- ask
    _ <-
      liftIO $
        ( try (runRedisAction redisInfo $ setex (pack . show $ uid) 3600 (serializeUser user))
            :: IO (Either SomeException (Either Reply Status))
        )
    return ()

  getCachedUser (UserId uid) = RedisCacheService $ do
    redisInfo <- ask
    eResult <-
      liftIO $
        ( try (runRedisAction redisInfo $ get (pack . show $ uid))
            :: IO (Either SomeException (Either Reply (Maybe ByteString)))
        )
    return $ case eResult of
      Right (Right (Just userString)) -> deserializeUser uid userString
      _                               -> Nothing

  invalidateUser (UserId uid) = RedisCacheService $ do
    redisInfo <- ask
    _ <-
      liftIO $
        ( try (runRedisAction redisInfo $ del [pack . show $ uid])
            :: IO (Either SomeException (Either Reply Integer))
        )
    return ()
