module Application.UseCase.ListUrls
  ( ListUrlsUseCase (..)
  , listUrls
  ) where

import Data.Map (Map)

import Domain.Entity.Url (Url, UrlId)
import Domain.Repository.UrlRepository (UrlRepository (..))

class (Monad m) => ListUrlsUseCase m where
  listUrlsUC :: m (Map UrlId Url)

listUrls :: (UrlRepository m) => m (Map UrlId Url)
listUrls = getAllUrls
