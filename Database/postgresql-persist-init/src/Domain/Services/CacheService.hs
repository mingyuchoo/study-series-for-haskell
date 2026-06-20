module Domain.Services.CacheService
    ( CacheService (..)
    ) where

import           Domain.Entities.User

-- Cache service interface (port)
class (Monad m) => CacheService m where
  cacheUser :: UserId -> User -> m ()
  getCachedUser :: UserId -> m (Maybe User)
  invalidateUser :: UserId -> m ()
