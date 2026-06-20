module Application.UseCase.ShortenUrl
  ( ShortenUrlUseCase (..)
  , shortenUrl
  ) where

import Domain.Entity.Url (TempUrl, UrlId)
import Domain.Repository.UrlRepository (UrlRepository (..))

class (Monad m) => ShortenUrlUseCase m where
  shortenUrlUC :: TempUrl -> m UrlId

shortenUrl :: (UrlRepository m) => TempUrl -> m UrlId
shortenUrl = storeUrl
