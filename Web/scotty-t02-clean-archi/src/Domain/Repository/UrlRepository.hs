module Domain.Repository.UrlRepository
  ( UrlRepository (..)
  ) where

import Data.Map (Map)

import Domain.Entity.Url (TempUrl, Url, UrlId)

class (Monad m) => UrlRepository m where
  storeUrl :: TempUrl -> m UrlId
  findUrl :: UrlId -> m (Maybe Url)
  getAllUrls :: m (Map UrlId Url)
