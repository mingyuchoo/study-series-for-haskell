module Application.UseCase.RetrieveUrl
  ( RetrieveUrlUseCase (..)
  , retrieveUrl
  ) where

import Domain.Entity.Url (Url, UrlId)
import Domain.Repository.UrlRepository (UrlRepository (..))

class (Monad m) => RetrieveUrlUseCase m where
  retrieveUrlUC :: UrlId -> m (Maybe Url)

retrieveUrl :: (UrlRepository m) => UrlId -> m (Maybe Url)
retrieveUrl = findUrl
