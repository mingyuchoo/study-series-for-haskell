{-# LANGUAGE OverloadedStrings #-}

module Infrastructure.Repository.RedisUrlRepository
  ( RedisUrlRepo
  , createRedisConnection
  , runRedisUrlRepo
  ) where

import Control.Monad.IO.Class (MonadIO, liftIO)

import Data.Aeson (decode, encode)
import Data.ByteString.Lazy qualified as LBS
import Data.Map (Map)
import Data.Map qualified as M
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding qualified as TE
import Data.Time (getCurrentTime)

import Database.Redis
  ( ConnectInfo (..)
  , Connection
  , Redis
  , connect
  , defaultConnectInfo
  , get
  , hgetall
  , incr
  , runRedis
  , set
  )

import Domain.Entity.Url
  ( TempUrl (..)
  , Url (..)
  , UrlId
  , generateShortUrl
  , mkUrlWithMetadata
  )
import Domain.Repository.UrlRepository (UrlRepository (..))
import System.Environment (lookupEnv)

newtype RedisUrlRepo a = RedisUrlRepo { runRepo :: Connection -> IO a }

instance Functor RedisUrlRepo where
  fmap f (RedisUrlRepo action) = RedisUrlRepo $ \conn -> fmap f (action conn)

instance Applicative RedisUrlRepo where
  pure x = RedisUrlRepo $ \_ -> pure x
  (RedisUrlRepo f) <*> (RedisUrlRepo x) = RedisUrlRepo $ \conn -> f conn <*> x conn

instance Monad RedisUrlRepo where
  (RedisUrlRepo action) >>= f = RedisUrlRepo $ \conn -> do
    result <- action conn
    runRepo (f result) conn

instance MonadIO RedisUrlRepo where
  liftIO action = RedisUrlRepo $ \_ -> action

instance UrlRepository RedisUrlRepo where
  storeUrl tempUrl = RedisUrlRepo $ \conn -> do
    currentTime <- getCurrentTime
    result <- runRedis conn $ do
      nextIdResult <- incr "url:counter"
      case nextIdResult of
        Left err -> error $ "Redis error: " ++ show err
        Right nextId -> do
          let urlId = fromIntegral nextId
              shortUrl = generateShortUrl urlId
              urlWithMetadata = mkUrlWithMetadata urlId (getTempUrl tempUrl) shortUrl currentTime
              urlKey = "url:" <> T.pack (show urlId)
              urlJson = LBS.toStrict $ encode urlWithMetadata
          setResult <- set (TE.encodeUtf8 urlKey) urlJson
          case setResult of
            Left err -> error $ "Redis error: " ++ show err
            Right _  -> return urlId
    return result

  findUrl urlId = RedisUrlRepo $ \conn -> do
    let urlKey = "url:" <> T.pack (show urlId)
    result <- runRedis conn $ get (TE.encodeUtf8 urlKey)
    case result of
      Left _ -> return Nothing
      Right Nothing -> return Nothing
      Right (Just urlJson) ->
        case decode (LBS.fromStrict urlJson) of
          Nothing  -> return Nothing
          Just url -> return (Just url)

  getAllUrls = RedisUrlRepo $ \conn -> do
    -- This is a simplified implementation
    -- In production, you might want to use SCAN for better performance
    counterResult <- runRedis conn $ get "url:counter"
    case counterResult of
      Left _ -> return M.empty
      Right Nothing -> return M.empty
      Right (Just counterBytes) -> do
        let counter = read $ T.unpack $ TE.decodeUtf8 counterBytes
        urls <-
          mapM
            ( \i -> do
                let urlKey = "url:" <> T.pack (show i)
                result <- runRedis conn $ get (TE.encodeUtf8 urlKey)
                case result of
                  Left _ -> return Nothing
                  Right Nothing -> return Nothing
                  Right (Just urlJson) ->
                    case decode (LBS.fromStrict urlJson) of
                      Nothing  -> return Nothing
                      Just url -> return (Just (i, url))
            )
            [1 .. counter]
        return $ M.fromList [(i, url) | Just (i, url) <- urls]

createRedisConnection :: IO Connection
createRedisConnection = do
  host <- fromMaybe "localhost" <$> lookupEnv "REDIS_HOST"
  connect defaultConnectInfo {connectHost = host}

runRedisUrlRepo :: RedisUrlRepo a -> Connection -> IO a
runRedisUrlRepo = runRepo
