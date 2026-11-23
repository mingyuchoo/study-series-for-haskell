module Domain.Services.CacheService
    ( CacheService (..)
    ) where

import           Domain.Entities.User

class (Monad m) => CacheService m where
  cacheUser :: UserId -> User -> m ()
  getCachedUser :: UserId -> m (Maybe User)
  invalidateUser :: UserId -> m ()
