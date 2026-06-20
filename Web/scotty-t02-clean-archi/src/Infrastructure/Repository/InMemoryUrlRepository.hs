{-# LANGUAGE OverloadedStrings #-}

module Infrastructure.Repository.InMemoryUrlRepository
  ( InMemoryUrlRepo
  , runInMemoryUrlRepo
  ) where

import Control.Monad.IO.Class (MonadIO, liftIO)

import Data.IORef (IORef, modifyIORef, readIORef)
import Data.Map (Map)
import Data.Map qualified as M
import Data.Time (getCurrentTime)

import Domain.Entity.Url
  ( TempUrl (..)
  , Url (..)
  , UrlId
  , generateShortUrl
  , mkUrlWithMetadata
  )
import Domain.Repository.UrlRepository (UrlRepository (..))

type UrlStore = (Int, Map UrlId Url)

newtype InMemoryUrlRepo a = InMemoryUrlRepo { runRepo :: IORef UrlStore -> IO a }

instance Functor InMemoryUrlRepo where
  fmap f (InMemoryUrlRepo action) = InMemoryUrlRepo $ \ref -> fmap f (action ref)

instance Applicative InMemoryUrlRepo where
  pure x = InMemoryUrlRepo $ \_ -> pure x
  (InMemoryUrlRepo f) <*> (InMemoryUrlRepo x) = InMemoryUrlRepo $ \ref -> f ref <*> x ref

instance Monad InMemoryUrlRepo where
  (InMemoryUrlRepo action) >>= f = InMemoryUrlRepo $ \ref -> do
    result <- action ref
    runRepo (f result) ref

instance MonadIO InMemoryUrlRepo where
  liftIO action = InMemoryUrlRepo $ \_ -> action

instance UrlRepository InMemoryUrlRepo where
  storeUrl tempUrl = InMemoryUrlRepo $ \ref -> do
    (nextId, urls) <- readIORef ref
    currentTime <- getCurrentTime
    let shortUrl = generateShortUrl nextId
        url = mkUrlWithMetadata nextId (getTempUrl tempUrl) shortUrl currentTime
        newUrls = M.insert nextId url urls
    modifyIORef ref $ \_ -> (nextId + 1, newUrls)
    return nextId

  findUrl urlId = InMemoryUrlRepo $ \ref -> do
    (_, urls) <- readIORef ref
    return $ M.lookup urlId urls

  getAllUrls = InMemoryUrlRepo $ \ref -> do
    (_, urls) <- readIORef ref
    return urls

runInMemoryUrlRepo :: InMemoryUrlRepo a -> IORef UrlStore -> IO a
runInMemoryUrlRepo = runRepo
